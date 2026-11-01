// Portcullis additions to Pode.Web (served from public/ by Pode).

// When the sidebar is collapsed to icons, the page names are hidden: show each one as a tooltip.
document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('#sidebar-list a.nav-link').forEach(function (link) {
        if (!link.title) {
            link.title = link.textContent.trim();
        }
    });
});
