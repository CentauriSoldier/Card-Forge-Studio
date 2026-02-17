(function () {
    var currentKey = null;

    function buildSidebar() {
        var holder = document.getElementById('tutorialNav');
        if (!holder || !window.TUTORIAL_DATA || !window.TUTORIAL_DATA.sections) {
            return;
        }

        var sections = window.TUTORIAL_DATA.sections;

        var html = '';
        html += '<div class="accordion" id="tutorialAccordion">';

        for (var sectionName in sections) {
            if (!Object.prototype.hasOwnProperty.call(sections, sectionName)) {
                continue;
            }

            var safe = sectionName.replace(/\W/g, '_');
            var headingId = 'tutorialHeading_' + safe;
            var collapseId = 'tutorialCollapse_' + safe;

            html += '    <div class="accordion-item">';
            html += '        <h2 class="accordion-header" id="' + headingId + '">';
            html += '            <button class="accordion-button collapsed" type="button"';
            html += '                data-bs-toggle="collapse" data-bs-target="#' + collapseId + '"';
            html += '                aria-expanded="false" aria-controls="' + collapseId + '">';
            html +=                  sectionName;
            html += '            </button>';
            html += '        </h2>';

            html += '        <div id="' + collapseId + '" class="accordion-collapse collapse"';
            html += '            aria-labelledby="' + headingId + '" data-bs-parent="#tutorialAccordion">';
            html += '            <div class="accordion-body p-0">';
            html += '                <div class="list-group list-group-flush">';

            var items = sections[sectionName].items || {};
            for (var key in items) {
                if (!Object.prototype.hasOwnProperty.call(items, key)) {
                    continue;
                }

                var item = items[key];
                html += '                    <a href="#" class="list-group-item list-group-item-action" data-key="' + key + '">';
                html +=                          (item.title || key);
                html += '                    </a>';
            }

            html += '                </div>';
            html += '            </div>';
            html += '        </div>';
            html += '    </div>';
        }

        html += '</div>';

        holder.innerHTML = html;

        wireSidebarClicks();
    }


    function wireSidebarClicks() {
        var links = document.querySelectorAll('#tutorialNav [data-key]');
        for (var i = 0; i < links.length; i++) {
            links[i].addEventListener('click', function (e) {
                e.preventDefault();
                loadTutorial(this.getAttribute('data-key'));
            });
        }
    }

    function loadTutorial(key) {
        var data = window.TUTORIAL_DATA;
        if (!data || !data.sections) return;

        for (var s in data.sections) {
            if (!Object.prototype.hasOwnProperty.call(data.sections, s)) continue;

            var items = data.sections[s].items || {};
            if (items[key]) {
                currentKey = key;

                var html = decodeHTML(items[key].html_b64);
                document.getElementById('tutorialContent').innerHTML = html;

                highlightActive(key);
                updatePrevNext();

                if (window.Prism) {
                    Prism.highlightAllUnder(document.getElementById('tutorialContent'));
                }
                return;
            }
        }
    }

    function highlightActive(key) {
        var links = document.querySelectorAll('#tutorialNav [data-key]');
        for (var i = 0; i < links.length; i++) {
            var active = links[i].getAttribute('data-key') === key;
            links[i].classList.toggle('active', active);

            if (active) {
                var collapse = links[i].closest('.accordion-collapse');
                if (collapse && !collapse.classList.contains('show')) {
                    new bootstrap.Collapse(collapse, { toggle: true });
                }
            }
        }
    }

    function updatePrevNext() {
        var order = window.TUTORIAL_DATA.order || [];
        var idx = order.indexOf(currentKey);

        var prev = document.getElementById('btnPrev');
        var next = document.getElementById('btnNext');

        if (prev) {
            prev.disabled = idx <= 0;
            prev.onclick = function () {
                if (idx > 0) loadTutorial(order[idx - 1]);
            };
        }

        if (next) {
            next.disabled = idx >= order.length - 1;
            next.onclick = function () {
                if (idx < order.length - 1) loadTutorial(order[idx + 1]);
            };
        }
    }

    function decodeHTML(b64) {
        if (!b64) return "";
        try {
            return decodeURIComponent(
                Array.prototype.map.call(atob(b64), function (c) {
                    return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
                }).join('')
            );
        } catch (e) {
            console.error("Base64 decode failed", e);
            return "";
        }
    }

    //can optionally use : to scroll to item in new section loaded (g.g., #build-a-forge:materials)
    document.addEventListener('click', function (e) {
        var a = e.target.closest('a[href^="#"]');
        if (!a) return;

        var hash = a.getAttribute('href').slice(1);
        if (!hash) return;

        var parts = hash.split(':');
        var key = parts[0];
        var anchor = parts[1] || null;

        // only hijack if this is a real tutorial key
        if (!window.TUTORIAL_DATA ||
            !window.TUTORIAL_DATA.order ||
            window.TUTORIAL_DATA.order.indexOf(key) === -1) {
            return;
        }

        e.preventDefault();
        loadTutorial(key);

        if (anchor) {
            setTimeout(function () {
                var el = document.getElementById(anchor);
                if (el) el.scrollIntoView({ behavior: 'smooth' });
            }, 0);
        }
    });




    document.addEventListener('DOMContentLoaded', function () {
        if (!window.TUTORIAL_DATA) return;

        buildSidebar();

        var first = (window.TUTORIAL_DATA.order && window.TUTORIAL_DATA.order[0]) ? window.TUTORIAL_DATA.order[0] : null;
        if (first) loadTutorial(first);
    });
})();
