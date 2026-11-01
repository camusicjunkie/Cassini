// Portcullis additions to Pode.Web (served from public/ by Pode).

document.addEventListener('DOMContentLoaded', function () {
    // When the sidebar is collapsed to icons the page names are hidden: show each one as a tooltip.
    document.querySelectorAll('#sidebar-list a.nav-link').forEach(function (link) {
        if (!link.title) {
            link.title = link.textContent.trim();
        }
    });

    keepSidebarState();
    addThemeToggle();
});

// Pode.Web forgets a collapsed sidebar on every page load, so clicking an icon in the rail
// re-opened the full sidebar. Remember the choice in this browser and reapply it on load.
function keepSidebarState() {
    var sidebar = document.querySelector('nav#sidebarMenu');
    var main = document.querySelector('main[role="main"]');
    var toggle = document.querySelector('button#menu-toggle');
    if (!sidebar || !main || !toggle) {
        return;
    }

    var key = 'portcullis.sidebar';
    var stored = null;
    try { stored = window.localStorage.getItem(key); } catch (e) { stored = null; }

    if (stored === 'rail' && !sidebar.classList.contains('hide')) {
        sidebar.classList.add('hide');
        main.classList.add('fullscreen');
    }

    // Pode.Web's own click handler toggles the classes; record the state after it has run.
    toggle.addEventListener('click', function () {
        setTimeout(function () {
            var state = sidebar.classList.contains('hide') ? 'rail' : 'open';
            try { window.localStorage.setItem(key, state); } catch (e) { }
        }, 0);
    });
}

// Light/dark switch in the top bar. Pode.Web keeps the choice in its own theme cookie
// (setPodeTheme), so it applies on every page and survives a reload. 'auto' follows the OS until
// the first click.
function addThemeToggle() {
    var bar = document.querySelector('nav.navbar .container-fluid');
    if (!bar || document.getElementById('pc-theme-toggle')) {
        return;
    }

    var button = document.createElement('button');
    button.type = 'button';
    button.id = 'pc-theme-toggle';
    bar.appendChild(button);

    function current() {
        var theme = document.body.getAttribute('pode-theme');
        if (theme === 'dark' || theme === 'light') {
            return theme;
        }
        return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }

    function render() {
        var dark = current() === 'dark';
        // Show what a click switches to.
        button.innerHTML = '<span class="mdi ' + (dark ? 'mdi-weather-sunny' : 'mdi-weather-night') + '"></span>';
        button.title = dark ? 'Switch to light mode' : 'Switch to dark mode';
        button.setAttribute('aria-label', button.title);
    }

    button.addEventListener('click', function () {
        var next = current() === 'dark' ? 'light' : 'dark';
        if (typeof setPodeTheme === 'function') {
            setPodeTheme(next, true);
        }
        else {
            document.body.setAttribute('pode-theme', next);
        }
        render();
        button.blur();
    });

    render();
}
