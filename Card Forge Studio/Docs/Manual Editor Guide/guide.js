'use strict';
(() => {
    const pages = [...document.querySelectorAll('section[data-topic]')];
    const links = [...document.querySelectorAll('nav a')];
    const search = document.getElementById('search');
    const searchView = document.getElementById('search-view');
    const results = document.getElementById('results');
    const status = document.getElementById('status');
    const previous = document.getElementById('previous');
    const next = document.getElementById('next');
    const index = pages.map(page => ({id: page.id, title: page.dataset.topic, text: page.textContent.replace(/\s+/g, ' ').trim()}));
    function show() {
        search.value = ''; searchView.hidden = true;
        const id = location.hash.slice(1); const page = pages.find(item => item.id === id) || pages[0];
        pages.forEach(item => { item.hidden = item !== page; });
        links.forEach(link => { if (link.hash === '#' + page.id) link.setAttribute('aria-current', 'page'); else link.removeAttribute('aria-current'); });
        const position = pages.indexOf(page);
        previous.hidden = position === 0; next.hidden = position === pages.length - 1;
        if (position > 0) { previous.href = '#' + pages[position - 1].id; previous.textContent = '← ' + pages[position - 1].dataset.topic; }
        if (position < pages.length - 1) { next.href = '#' + pages[position + 1].id; next.textContent = pages[position + 1].dataset.topic + ' →'; }
        document.querySelector('footer').hidden = false;
        document.title = page.dataset.topic + ' · Manual Editor Guide';
        window.scrollTo(0, 0);
    }
    search.addEventListener('input', () => {
        const query = search.value.trim().toLowerCase();
        if (!query) { show(); search.focus(); return; }
        pages.forEach(page => { page.hidden = true; }); links.forEach(link => link.removeAttribute('aria-current'));
        searchView.hidden = false; document.querySelector('footer').hidden = true; results.replaceChildren();
        const terms = query.split(/\s+/);
        for (const entry of index.filter(entry => terms.every(term => entry.text.toLowerCase().includes(term)))) {
            const link = document.createElement('a'); link.href = '#' + entry.id;
            const title = document.createElement('strong'); title.textContent = entry.title;
            const excerpt = document.createElement('small'); const match = entry.text.toLowerCase().indexOf(terms[0]);
            const start = Math.max(0, match - 65); excerpt.textContent = (start ? '…' : '') + entry.text.slice(start, start + 210) + '…';
            link.append(title, excerpt); results.append(link);
        }
        status.textContent = results.children.length ? results.children.length + ' matching topics' : 'No matching topics. Try “styles”, “table”, “glossary”, or “export”.';
    });
    document.addEventListener('click', event => {
        const link = event.target.closest('a[href^="#"]');
        if (link && link.hash === location.hash) show();
    });
    document.addEventListener('keydown', event => {
        if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'f') { event.preventDefault(); search.focus(); search.select(); }
        if (event.key === 'Escape' && document.activeElement === search) { show(); search.focus(); }
    });
    for (const block of document.querySelectorAll('pre')) {
        const button = document.createElement('button'); button.type = 'button'; button.textContent = 'Copy'; button.setAttribute('aria-label', 'Copy example');
        button.addEventListener('click', async () => {
            try { await navigator.clipboard.writeText(block.querySelector('code').textContent); button.textContent = 'Copied'; }
            catch (_) { const selection = window.getSelection(); const range = document.createRange(); range.selectNodeContents(block.querySelector('code')); selection.removeAllRanges(); selection.addRange(range); button.textContent = 'Press Ctrl+C'; }
            setTimeout(() => { button.textContent = 'Copy'; }, 2200);
        }); block.append(button);
    }
    window.addEventListener('hashchange', show); show();
})();
