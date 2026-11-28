'use strict';
window.CFSManualAppearance = {
    sections(container) {
        const nodes = Array.from(container.childNodes);
        const stack = [];
        for (const node of nodes) {
            if (/^H[1-6]$/.test(node.nodeName)) {
                const level = Number(node.nodeName.slice(1));
                let title = node;
                if (level === 2) { title = document.createElement('h1'); for (const attribute of node.attributes) title.setAttribute(attribute.name, attribute.value); title.append(...node.childNodes); node.remove(); }
                while (stack.length && stack[stack.length - 1].level >= level) stack.pop();
                const section = document.createElement('section');
                section.className = 'manual-section manual-heading-level-' + level + ' section-level-' + (level === 1 ? 2 : level) + (level > 3 ? ' inset-section' : ' metal-panel');
                if (title.id) section.dataset.section = title.id;
                const heading = document.createElement('div'); heading.className = 'section-heading';
                const anchor = document.createElement('span'); anchor.className = 'heading-anchor'; anchor.setAttribute('aria-hidden', 'true');
                heading.append(anchor, title);
                const body = document.createElement('div'); body.className = 'section-copy';
                section.append(heading, body);
                (stack.length ? stack[stack.length - 1].section : container).append(section);
                stack.push({level, section, body});
            } else if (stack.length) stack[stack.length - 1].body.append(node);
        }
        container.querySelectorAll('table').forEach(table => table.classList.add('table'));
    }
};
let manualAppearanceRevision = 0;
document.addEventListener('manual-editor-options', event => {
    if (!event.detail || event.detail.revision <= manualAppearanceRevision) return;
    manualAppearanceRevision = event.detail.revision;
    const style = document.getElementById('manual-appearance-styles');
    if (typeof event.detail.appearanceCSS === 'string' && style.textContent !== event.detail.appearanceCSS) style.textContent = event.detail.appearanceCSS;
});
document.addEventListener('DOMContentLoaded', () => {
    const tools = document.querySelector('.markdown-tools');
    const button = document.createElement('button'); button.type = 'button'; button.className = 'btn btn-outline-light'; button.textContent = 'Appearance…';
    button.addEventListener('click', () => { window.location.href = 'cfsmanual://appearance'; });
    tools?.append(button);
});
