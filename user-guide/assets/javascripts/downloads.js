/*
   Fills the download cards on the homepage from latest.json.

   latest.json is written by .github/workflows/publish-latest.yml (see DOCS.md).
   Without JavaScript, or when the fetch fails (no file yet, offline preview from
   file://, a network error, a file this script does not understand), the page is
   left exactly as the Markdown wrote it: every card links to the releases/latest
   page.  Nothing here is required for the page to work.

   No framework, no CDN.  Everything from the file is inserted with textContent
   or setAttribute, never as HTML, and a download link is used only if it points
   at this project's own release downloads.
*/
(function () {
   "use strict";

   var DOWNLOAD_PREFIX = "https://github.com/TR4W/TR4W-D12/releases/download/";
   var RELEASES_LATEST = "https://github.com/TR4W/TR4W-D12/releases/latest";

   function element(tag, className, text) {
      var node = document.createElement(tag);
      if (className) {
         node.className = className;
      }
      if (text) {
         node.textContent = text;
      }
      return node;
   }

   function formatSize(bytes) {
      if (typeof bytes !== "number" || bytes <= 0) {
         return "";
      }
      return (bytes / (1024 * 1024)).toFixed(1) + " MB";
   }

   function formatDate(text) {
      var when = new Date(text);
      if (isNaN(when.getTime())) {
         return "";
      }
      return when.toISOString().slice(0, 10);
   }

   function usableFile(file) {
      return file && typeof file.name === "string" && typeof file.url === "string" &&
         file.url.indexOf(DOWNLOAD_PREFIX) === 0;
   }

   function fileBlock(file, version) {
      var block = element("div", "tr4w-download-file");
      var button = element("a", "tr4w-button", "Download " + file.name);
      button.setAttribute("href", file.url);
      block.appendChild(button);
      var facts = [version ? "Version " + version : "", formatSize(file.size)].filter(Boolean);
      block.appendChild(element("p", "tr4w-download-what", file.description || ""));
      if (facts.length > 0) {
         block.appendChild(element("p", "tr4w-download-facts", facts.join(" · ")));
      }
      if (typeof file.sha256 === "string" && /^[0-9a-f]{64}$/.test(file.sha256)) {
         var details = element("details", "tr4w-download-sha");
         details.appendChild(element("summary", "", "SHA-256"));
         details.appendChild(element("code", "", file.sha256));
         block.appendChild(details);
      }
      return block;
   }

   function fillCard(card, platform, version) {
      var target = card.querySelector(".tr4w-download-files");
      if (!target || !platform) {
         return;
      }
      var files = (platform.files || []).filter(usableFile);
      if (platform.available && files.length > 0) {
         var fresh = document.createDocumentFragment();
         files.forEach(function (file) {
            fresh.appendChild(fileBlock(file, version));
         });
         (platform.missing || []).forEach(function (gap) {
            if (gap && typeof gap.reason === "string") {
               fresh.appendChild(element("p", "tr4w-download-gap", gap.reason));
            }
         });
         target.textContent = "";
         target.appendChild(fresh);
         return;
      }
      if (platform.available === false) {
         card.classList.add("is-absent");
         target.textContent = "";
         target.appendChild(element("p", "tr4w-download-gap",
            typeof platform.reason === "string" ? platform.reason : "Not available in the latest release."));
         var more = element("a", "tr4w-text-link", "Check the release page");
         more.setAttribute("href", RELEASES_LATEST);
         target.appendChild(more);
      }
   }

   function apply(data) {
      if (!data || data.schema !== 1 || !data.platforms) {
         return;
      }
      var version = typeof data.version === "string" ? data.version : "";
      var cards = document.querySelectorAll("[data-platform]");
      Array.prototype.forEach.call(cards, function (card) {
         fillCard(card, data.platforms[card.getAttribute("data-platform")], version);
      });
      var line = document.querySelector(".tr4w-latest-line");
      if (line && version) {
         var date = formatDate(data.published);
         line.textContent = "Latest release: TR4W " + version + (date ? ", published " + date : "") + ".";
         line.hidden = false;
      }
   }

   function start() {
      if (!document.querySelector("[data-platform]") || typeof fetch !== "function") {
         return;
      }
      // Relative to the page, so the hosted site reads its own latest.json.
      // A failure of any kind leaves the Markdown fallback in place.
      fetch("latest.json", { cache: "no-cache" })
         .then(function (response) {
            if (!response.ok) {
               throw new Error("latest.json: HTTP " + response.status);
            }
            return response.json();
         })
         .then(apply)
         .catch(function () {});
   }

   if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", start);
   } else {
      start();
   }
})();
