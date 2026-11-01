// Cassini additions to Pode.Web (served from public/ by Pode).

// Pode.Web empties a table and shows its spinner the moment a refresh starts (the Status page's
// minute timer, a refresh button, Sync-PodeWebTable), then fills it when the data arrives. The
// card collapses and grows back: a flash. Keep the current rows on screen until the new ones
// replace them, which Pode.Web's updateTable does in one step. A first load, with no rows yet,
// still shows the spinner.
keepRowsWhileRefreshing();

function keepRowsWhileRefreshing() {
    if (typeof PodeTable !== 'function' || PodeTable.prototype.cassiniKeepsRows) {
        return;
    }

    var load = PodeTable.prototype.load;
    PodeTable.prototype.load = function (data, sender, opts) {
        var body = this.element ? this.element.find('table tbody') : null;
        var rows = body && body.length ? body.children('tr').detach() : null;

        this.cassiniHasRows = !!(rows && rows.length);
        var result = load.call(this, data, sender, opts);
        this.cassiniHasRows = false;

        // Only if the table is still waiting: a static table is filled within the call itself.
        if (rows && rows.length && body.children('tr').length === 0) {
            body.append(rows);
        }
        return result;
    };

    // The spinner sits under the table and pushes the card taller; with rows still showing, the
    // refresh needs no spinner. Pode.Web turns it on again when it sends the request.
    var spinner = PodeTable.prototype.spinner;
    PodeTable.prototype.spinner = function (show) {
        if (show && (this.cassiniHasRows || (this.element && this.element.find('table tbody tr').length > 0))) {
            return;
        }
        return spinner.call(this, show);
    };
    PodeTable.prototype.cassiniKeepsRows = true;
}

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

    var key = 'cassini.sidebar';
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
    if (!bar || document.getElementById('cs-theme-toggle')) {
        return;
    }

    var button = document.createElement('button');
    button.type = 'button';
    button.id = 'cs-theme-toggle';
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

// ------------------------------------------------------------------ Patch calendar
// The Calendar page holds an empty <div id="cs-calendar">; this draws the month from
// /api/v1/calendar. Pode.Web adds page content after the page loads, so wait for the element.
(function () {
    var weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    var kindLabel = { release: 'Release', auto: 'Automatic', action: 'You do', install: 'Install' };

    function watchForCalendar() {
        var start = function () {
            var host = document.getElementById('cs-calendar');
            if (host && !host.getAttribute('data-ready')) {
                host.setAttribute('data-ready', '1');
                new PatchCalendar(host).load(null);
            }
        };
        start();
        new MutationObserver(start).observe(document.body, { childList: true, subtree: true });
    }

    function el(tag, className, text) {
        var node = document.createElement(tag);
        if (className) { node.className = className; }
        if (text !== undefined && text !== null) { node.textContent = text; }
        return node;
    }

    function pad(n) { return (n < 10 ? '0' : '') + n; }
    function iso(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
    function parseIso(s) { var p = s.split('-'); return new Date(+p[0], +p[1] - 1, +(p[2] || 1)); }

    function PatchCalendar(host) {
        this.host = host;
        this.data = null;
        this.selected = null;
    }

    PatchCalendar.prototype.load = function (month) {
        var self = this;
        var base = document.body.getAttribute('pode-app-path') || '';
        var url = base + '/api/v1/calendar' + (month ? '?month=' + encodeURIComponent(month) : '');
        if (!this.data) {
            this.host.replaceChildren(el('p', 'cs-cal-loading', 'Loading the calendar…'));
        }
        this.host.setAttribute('aria-busy', 'true');
        fetch(url, { credentials: 'same-origin', headers: { Accept: 'application/json' } })
            .then(function (r) {
                if (!r.ok) { throw new Error('The server answered ' + r.status + '.'); }
                return r.json();
            })
            .then(function (data) {
                self.data = data;
                var monthOfToday = data.today.slice(0, 7) === data.month;
                var patchTuesday = (data.events || []).filter(function (e) { return e.Kind === 'release'; })[0];
                self.selected = monthOfToday ? data.today : (patchTuesday ? patchTuesday.Date : data.month + '-01');
                self.render();
            })
            .catch(function (err) {
                self.host.replaceChildren(el('p', 'cs-cal-error', 'The calendar could not be loaded. ' + err.message));
            })
            .finally(function () { self.host.removeAttribute('aria-busy'); });
    };

    PatchCalendar.prototype.shift = function (months) {
        var d = parseIso(this.data.month);
        d.setMonth(d.getMonth() + months);
        this.load(d.getFullYear() + '-' + pad(d.getMonth() + 1));
    };

    PatchCalendar.prototype.eventsOn = function (day) {
        return (this.data.events || []).filter(function (e) { return e.Date === day; });
    };

    PatchCalendar.prototype.render = function () {
        var self = this;
        var data = this.data;
        var first = parseIso(data.month);
        var title = first.toLocaleDateString('en-GB', { month: 'long', year: 'numeric' });

        // Toolbar: previous, month, next, today.
        var toolbar = el('div', 'cs-cal-toolbar');
        var nav = el('div', 'cs-cal-nav');
        var prev = el('button', 'cs-cal-step');
        prev.type = 'button';
        prev.setAttribute('aria-label', 'Previous month');
        prev.appendChild(el('span', 'mdi mdi-chevron-left'));
        prev.addEventListener('click', function () { self.shift(-1); });
        var next = el('button', 'cs-cal-step');
        next.type = 'button';
        next.setAttribute('aria-label', 'Next month');
        next.appendChild(el('span', 'mdi mdi-chevron-right'));
        next.addEventListener('click', function () { self.shift(1); });
        nav.append(prev, el('h2', 'cs-cal-title', title), next);
        var today = el('button', 'cs-cal-today', 'Today');
        today.type = 'button';
        today.disabled = data.today.slice(0, 7) === data.month && this.selected === data.today;
        today.addEventListener('click', function () {
            if (data.today.slice(0, 7) === data.month) { self.select(data.today, true); } else { self.load(null); }
        });
        toolbar.append(nav, today);

        var parts = [toolbar];
        (data.warnings || []).forEach(function (w) {
            var warn = el('div', 'cs-cal-warning');
            warn.setAttribute('role', 'note');
            warn.append(el('span', 'mdi mdi-alert-outline'), el('span', null, w));
            parts.push(warn);
        });

        // Month grid, weeks starting on Monday.
        var body = el('div', 'cs-cal-body');
        var grid = el('div', 'cs-cal-grid');
        grid.setAttribute('role', 'grid');
        grid.setAttribute('aria-label', title);
        weekdays.forEach(function (w) { grid.appendChild(el('div', 'cs-cal-weekday', w)); });

        var start = new Date(first);
        start.setDate(1 - ((first.getDay() + 6) % 7));
        this.cells = {};
        for (var i = 0; i < 42; i++) {
            var day = new Date(start);
            day.setDate(start.getDate() + i);
            if (i === 35 && day.getMonth() !== first.getMonth()) { break; }
            grid.appendChild(this.cell(day, day.getMonth() === first.getMonth()));
        }

        var side = el('aside', 'cs-cal-side');
        side.setAttribute('aria-live', 'polite');
        this.side = side;
        body.append(grid, side);
        parts.push(body, this.legend());

        this.host.replaceChildren.apply(this.host, parts);
        this.select(this.selected, false);
    };

    PatchCalendar.prototype.cell = function (day, inMonth) {
        var self = this;
        var key = iso(day);
        var events = this.eventsOn(key);
        var cell = el('button', 'cs-cal-day');
        cell.type = 'button';
        cell.setAttribute('role', 'gridcell');
        cell.setAttribute('data-date', key);
        if (!inMonth) { cell.classList.add('is-outside'); }
        if (key === this.data.today) { cell.classList.add('is-today'); cell.setAttribute('aria-current', 'date'); }
        if (events.length) { cell.classList.add('has-events'); }

        var label = day.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' });
        cell.setAttribute('aria-label', label + (events.length ? ', ' + events.map(function (e) { return e.Title; }).join(', ') : ''));

        cell.appendChild(el('span', 'cs-cal-num', String(day.getDate())));
        var list = el('span', 'cs-cal-chips');
        events.forEach(function (e) {
            var chip = el('span', 'cs-cal-chip kind-' + e.Kind + (e.Ring ? ' ring-' + e.Ring.toLowerCase() : ''));
            if (e.Time) { chip.append(el('span', 'cs-cal-chip-time', e.Time), document.createTextNode(' ')); }
            // An install chip is already coloured by ring; its ring name is the whole story.
            chip.appendChild(el('span', 'cs-cal-chip-title', e.Kind === 'install' && e.Ring ? e.Ring : e.Title));
            list.appendChild(chip);
        });
        cell.appendChild(list);

        cell.addEventListener('click', function () { self.select(key, true); });
        cell.addEventListener('keydown', function (ev) {
            var step = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 }[ev.key];
            if (!step) { return; }
            ev.preventDefault();
            var target = parseIso(key);
            target.setDate(target.getDate() + step);
            var targetKey = iso(target);
            if (self.cells[targetKey]) { self.select(targetKey, true); }
        });
        this.cells[key] = cell;
        return cell;
    };

    PatchCalendar.prototype.select = function (key, focus) {
        var self = this;
        Object.keys(this.cells).forEach(function (k) {
            var selected = k === key;
            self.cells[k].classList.toggle('is-selected', selected);
            self.cells[k].setAttribute('aria-selected', selected ? 'true' : 'false');
            self.cells[k].tabIndex = selected ? 0 : -1;
        });
        this.selected = key;
        if (focus && this.cells[key]) { this.cells[key].focus(); }
        var todayButton = this.host.querySelector('.cs-cal-today');
        if (todayButton) { todayButton.disabled = key === this.data.today; }
        this.renderSide(key);
    };

    PatchCalendar.prototype.renderSide = function (key) {
        var side = this.side;
        var day = parseIso(key);
        var heading = day.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' });
        var parts = [el('h3', 'cs-cal-side-title', heading)];

        var item = function (e, withDate) {
            var node = el('div', 'cs-cal-item kind-' + e.Kind + (e.Ring ? ' ring-' + e.Ring.toLowerCase() : ''));
            var head = el('div', 'cs-cal-item-head');
            head.appendChild(el('span', 'cs-cal-item-kind', kindLabel[e.Kind] || e.Kind));
            if (e.Time) { head.appendChild(el('span', 'cs-cal-item-time', e.Time)); }
            node.append(head, el('div', 'cs-cal-item-title', e.Title));
            if (withDate) {
                node.appendChild(el('div', 'cs-cal-item-date',
                    parseIso(e.Date).toLocaleDateString('en-GB', { weekday: 'short', day: 'numeric', month: 'short' })));
            }
            else {
                node.appendChild(el('div', 'cs-cal-item-detail', e.Detail));
            }
            return node;
        };

        var events = this.eventsOn(key);
        events.forEach(function (e) { parts.push(item(e, false)); });
        if (!events.length) {
            parts.push(el('p', 'cs-cal-empty', 'Nothing scheduled.'));
            // An empty day says what comes next instead.
            var later = (this.data.events || []).filter(function (e) { return e.Date > key; }).slice(0, 3);
            if (later.length) {
                parts.push(el('h4', 'cs-cal-upcoming', 'Coming up'));
                later.forEach(function (e) { parts.push(item(e, true)); });
            }
        }

        // Where the install times come from.
        var windows = el('div', 'cs-cal-windows');
        windows.appendChild(el('h4', null, 'Install windows (client local time)'));
        (this.data.schedule || []).forEach(function (s) {
            var row = el('div', 'cs-cal-window ring-' + s.Ring.toLowerCase());
            var when = (s.Day === 'Everyday' ? 'Every day' : s.Day) + ' ' + pad(s.Hour) + ':00';
            row.append(el('span', 'cs-cal-window-ring', s.Ring), el('span', 'cs-cal-window-when', when),
                el('span', 'cs-cal-window-source', s.Source + ', seen within ' + s.DetectionHours + ' h'));
            windows.appendChild(row);
        });
        parts.push(windows);
        side.replaceChildren.apply(side, parts);
    };

    PatchCalendar.prototype.legend = function () {
        var legend = el('div', 'cs-cal-legend');
        [['kind-release', 'Patch Tuesday'], ['kind-action', 'You do'], ['kind-auto', 'Automatic'],
            ['kind-install ring-pilot', 'Pilot'], ['kind-install ring-workstations', 'Workstations'],
            ['kind-install ring-servers', 'Servers']].forEach(function (pair) {
            var item = el('span', 'cs-cal-legend-item ' + pair[0]);
            item.append(el('span', 'cs-cal-dot'), el('span', null, pair[1]));
            legend.appendChild(item);
        });
        return legend;
    };

    document.addEventListener('DOMContentLoaded', watchForCalendar);
})();
