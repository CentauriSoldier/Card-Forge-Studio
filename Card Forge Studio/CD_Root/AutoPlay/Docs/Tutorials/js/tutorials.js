(function () {
    function getNavItems() {
        return [
            { key: 'home',               href: 'index.html',               label: 'Home' },
            { key: 'projects-create',    href: 'creating-a-project.html',  label: 'Creating a Project' },
            { key: 'forge-build',        href: 'building-a-forge.html',    label: 'Building a Forge' },
            { key: 'cardset-create',     href: 'creating-a-card-set.html', label: 'Creating a Card Set' },
            { key: 'cardset-edit',       href: 'editing-a-card-set.html',  label: 'Editing a Card Set' }
        ];
    }

    function getNavHTML(items) {
        var html = '';
        html += '<div class="list-group">';

        for (var i = 0; i < items.length; i++) {
            html += '<a href="' + items[i].href + '" class="list-group-item list-group-item-action" data-nav="' + items[i].key + '">'
                 + items[i].label
                 + '</a>';
        }

        html += '</div>';
        return html;
    }

    function setActive(navKey) {
        if (!navKey) {
            return;
        }

        var links = document.querySelectorAll('#tutorialNav [data-nav]');
        for (var i = 0; i < links.length; i++) {
            if (links[i].getAttribute('data-nav') === navKey) {
                links[i].classList.add('active');
                break;
            }
        }
    }
	
	(function () {
		function initCopyButtons() {
			var buttons = document.querySelectorAll('.copy-btn');

			for (var i = 0; i < buttons.length; i++) {
				(function (btn) {
					btn.addEventListener('click', function () {
						var pre = btn.nextElementSibling;
						if (!pre) {
							return;
						}

						var code = pre.querySelector('code');
						if (!code) {
							return;
						}

						navigator.clipboard.writeText(code.innerText);

						btn.textContent = 'Copied';

						setTimeout(function () {
							btn.textContent = 'Copy';
						}, 1500);
					});
				})(buttons[i]);
			}
		}

		if (document.readyState === 'loading') {
			document.addEventListener('DOMContentLoaded', initCopyButtons);
		} else {
			initCopyButtons();
		}
	})();


    function wirePrevNext(items, navKey) {
        var prev = document.getElementById('tutorialPrev');
        var next = document.getElementById('tutorialNext');

        if (!prev && !next) {
            return;
        }

        var index = -1;
        for (var i = 0; i < items.length; i++) {
            if (items[i].key === navKey) {
                index = i;
                break;
            }
        }

        if (prev) {
            if (index > 0) {
                prev.href = items[index - 1].href;
                prev.textContent = '← ' + items[index - 1].label;
                prev.classList.remove('d-none');
            } else {
                prev.classList.add('d-none');
            }
        }

        if (next) {
            if (index >= 0 && index < items.length - 1) {
                next.href = items[index + 1].href;
                next.textContent = items[index + 1].label + ' →';
                next.classList.remove('d-none');
            } else {
                next.classList.add('d-none');
            }
        }
    }
	
	var holder = document.getElementById('tutorialNav');
    if (!holder) {
        return;
    }

    var items = getNavItems();
    holder.innerHTML = getNavHTML(items);

    var navKey = document.body.getAttribute('data-nav-active');
    setActive(navKey);
    wirePrevNext(items, navKey);
})();
