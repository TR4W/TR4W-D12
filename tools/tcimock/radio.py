"""State and text protocol; no sockets, UI or real radio connections."""
from radiosim.core import RadioState

MODES = ('lsb', 'usb', 'cw', 'cwr', 'am', 'sam', 'fm', 'nfm', 'digu', 'digl', 'rtty')
RATE = 48000


def message(name, *values):
   args = ','.join(str(v).lower() if isinstance(v, bool) else str(v) for v in values)
   return name + (':' + args if args else '') + ';'


def integer(value, low, high):
   number = int(value)
   if not low <= number <= high:
      raise ValueError('value out of range')
   return number


def boolean(value):
   if value.lower() not in ('true', 'false'):
      raise ValueError('expected true or false')
   return value.lower() == 'true'


class Receiver(RadioState):
   def __init__(self, frequency):
      super().__init__(frequency, frequency + 5000, 'cw')
      self.rit_offset = 0
      self.xit_offset = 0
      self.rx_enable = True
      self.filter_low = -250
      self.filter_high = 250
      self.drive = 50
      self.agc_mode = 'normal'
      self.lock = False


class Radio:
   FLAGS = {'rit_enable': 'rit_on', 'xit_enable': 'xit_on',
            'split_enable': 'split', 'rx_enable': 'rx_enable', 'lock': 'lock'}
   NUMBERS = {'rit_offset': ('rit_offset', -9999, 9999),
              'xit_offset': ('xit_offset', -9999, 9999), 'drive': ('drive', 0, 100)}

   def __init__(self):
      self.receivers = [Receiver(14025000), Receiver(7025000)]
      self.speed = 25

   def burst(self):
      rows = [message('protocol', 'ExpertSDR3', '2.0'), message('device', 'TR4W-TCI-MOCK'),
              message('receive_only', False), message('trx_count', 2),
              message('channels_count', 2), message('vfo_limits', 100000, 60000000),
              message('if_limits', -RATE // 2, RATE // 2), message('modulations_list', *MODES),
              message('audio_samplerate', RATE), message('iq_samplerate', RATE),
              message('audio_stream_sample_type', 'float32'), message('audio_stream_channels', 2),
              message('audio_stream_samples', 2048), message('cw_macros_speed', self.speed)]
      for rx, state in enumerate(self.receivers):
         rows.extend([message('vfo', rx, 0, state.vfo_a), message('vfo', rx, 1, state.vfo_b),
                      message('dds', rx, state.vfo_a), message('modulation', rx, state.mode),
                      message('rx_filter_band', rx, state.filter_low, state.filter_high),
                      message('trx', rx, state.transmitting), message('tx_enable', rx, rx == 0),
                      message('agc_mode', rx, state.agc_mode)])
         rows.extend(message(name, rx, getattr(state, attr)) for name, attr in self.FLAGS.items())
         rows.extend(message(name, rx, getattr(state, spec[0])) for name, spec in self.NUMBERS.items())
      return rows + ['start;', 'ready;']

   def command(self, name, args):
      """Return (replies, changed); invalid commands raise ValueError, unknowns KeyError."""
      if name in ('cw_keyer_speed', 'cw_macros_speed'):
         if len(args) > 1:
            raise ValueError('speed takes one argument')
         if args:
            self.speed = integer(args[0], 5, 80)
         return [message('cw_macros_speed', self.speed), message('cw_keyer_speed', self.speed)], bool(args)
      if name in ('split_enable',) and len(args) == 1 and args[0].lower() in ('true', 'false'):
         args = ['0'] + args
      if not args:
         raise ValueError('receiver required')
      rx = integer(args[0], 0, 1)
      state = self.receivers[rx]
      values = args[1:]
      if name == 'vfo':
         if len(values) not in (1, 2):
            raise ValueError('vfo requires channel and optional frequency')
         channel = integer(values[0], 0, 1)
         attr = ('vfo_a', 'vfo_b')[channel]
         if len(values) == 2:
            setattr(state, attr, integer(values[1], 100000, 60000000))
         rows = [message(name, rx, channel, getattr(state, attr))]
         if channel == 0:
            rows.append(message('dds', rx, state.vfo_a))
         return rows, len(values) == 2
      if name == 'dds':
         if len(values) > 1:
            raise ValueError('dds takes frequency')
         if values:
            state.vfo_a = integer(values[0], 100000, 60000000)
         return [message(name, rx, state.vfo_a), message('vfo', rx, 0, state.vfo_a)], bool(values)
      if name == 'rx_filter_band':
         if len(values) not in (0, 2):
            raise ValueError('filter requires low and high')
         if values:
            low, high = (integer(v, -20000, 20000) for v in values)
            if low >= high:
               raise ValueError('filter low must be less than high')
            state.filter_low, state.filter_high = low, high
         return [message(name, rx, state.filter_low, state.filter_high)], bool(values)
      if name in self.FLAGS:
         if len(values) > 1:
            raise ValueError('flag takes one value')
         attr = self.FLAGS[name]
         if values:
            value = boolean(values[0])
            if attr == 'split':
               state.tx_vfo = 1 if value else 0
            else:
               setattr(state, attr, value)
         return [message(name, rx, getattr(state, attr))], bool(values)
      if name in self.NUMBERS:
         if len(values) > 1:
            raise ValueError('setting takes one value')
         attr, low, high = self.NUMBERS[name]
         if values:
            setattr(state, attr, integer(values[0], low, high))
         return [message(name, rx, getattr(state, attr))], bool(values)
      if name in ('modulation', 'agc_mode'):
         choices = MODES if name == 'modulation' else ('normal', 'fast', 'off')
         attr = 'mode' if name == 'modulation' else name
         if len(values) > 1 or (values and values[0].lower() not in choices):
            raise ValueError('unsupported ' + name)
         if values:
            setattr(state, attr, values[0].lower())
         return [message(name, rx, getattr(state, attr))], bool(values)
      raise KeyError(name)

   def status(self):
      return '\n'.join('RX%d A=%d B=%d mode=%s split=%s RIT=%s/%d XIT=%s/%d TX=%s' %
         (i, r.vfo_a, r.vfo_b, r.mode, r.split, r.rit_on, r.rit_offset,
          r.xit_on, r.xit_offset, r.transmitting) for i, r in enumerate(self.receivers))
