--[[!
@fqxn CFS.Modules.Exporter.Exporters.ExporterHTML.Assets
@desc Responsive gallery styling and browser interactions. These assets use local images and embedded JSON, so a gallery can open directly from disk without a server, network libraries, or fetch requests.
@vis private
!]]
return {
    css = [=[
*{box-sizing:border-box}body{margin:0;background:var(--page);color:var(--text);font:16px/1.5 system-ui,sans-serif}button,input,select{font:inherit}button,a,input,select{outline-offset:4px}button:focus-visible,a:focus-visible,input:focus-visible,select:focus-visible{outline:3px solid var(--accent)}button{cursor:pointer;background:var(--button-background);color:var(--button-text);border:1px solid var(--button-border);border-radius:10px;min-height:44px;padding:.55rem .9rem}button:hover{background:var(--button-hover)}button:disabled{cursor:default;opacity:.5}main{max-width:1440px;margin:auto;padding:clamp(1rem,3vw,3rem)}header{border:1px solid var(--border);border-radius:20px;padding:clamp(1.3rem,3vw,2.6rem);background:linear-gradient(120deg,var(--header-start),var(--header-end));margin-bottom:1.5rem}.eyebrow{color:var(--accent);letter-spacing:.12em;font-size:.8rem;font-weight:800;text-transform:uppercase;margin:0}h1{font-size:clamp(1.8rem,4vw,3rem);line-height:1.15;margin:.6rem 0}header p:last-child{color:var(--muted);margin-bottom:0}.tools{display:grid;grid-template-columns:2fr 1fr 1fr 1fr;gap:1rem;padding:1rem;background:var(--surface);border:1px solid var(--border);border-radius:16px}.tools label{display:flex;flex-direction:column;gap:.35rem;font-size:.85rem;font-weight:650}input,select{width:100%;min-width:0;background:var(--surface-raised);color:var(--text);border:1px solid var(--border);border-radius:9px;min-height:44px;padding:.6rem}.actions{display:flex;flex-wrap:wrap;gap:.6rem;align-items:center;margin:1rem 0 1.5rem}.actions p{flex:1;margin:0;color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,220px),1fr));gap:1.25rem}.card{min-width:0;border:1px solid var(--border);border-radius:16px;background:var(--surface);padding:.8rem;box-shadow:0 5px 18px #0002}.art{display:block;width:100%;padding:0;border:0;background:transparent;overflow:hidden;border-radius:10px}.art img{display:block;width:100%;height:auto;aspect-ratio:var(--ratio);object-fit:contain;background:var(--surface-raised)}.card h2{font-size:1.05rem;overflow-wrap:anywhere;margin:.8rem 0 .2rem}.card p{font-size:.85rem;color:var(--muted);margin:.25rem 0}.card .flip{width:100%;margin-top:.6rem}.missing{min-height:100px}.empty{text-align:center;padding:3rem;border:1px dashed var(--border);border-radius:16px;color:var(--muted)}#more{display:block;margin:1.5rem auto}dialog{background:var(--surface);color:var(--text);border:1px solid var(--border);border-radius:20px;padding:1.2rem;max-width:1000px;width:calc(100% - 2rem);max-height:calc(100% - 2rem);overflow:auto}dialog::backdrop{background:#000b}dialog .bar{display:flex;gap:.5rem;flex-wrap:wrap;margin-bottom:1rem}dialog .bar button:last-child{margin-left:auto}.detail{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:1.5rem}.detail img{width:100%;max-height:70vh;object-fit:contain;border-radius:10px;background:var(--surface-raised)}dl{margin:0}dt{font-weight:700;color:var(--accent);margin-top:.8rem}dd{margin:.2rem 0;white-space:pre-wrap;overflow-wrap:anywhere}.note{color:var(--muted);font-size:.85rem;margin-top:2rem} [hidden]{display:none!important}@media(max-width:850px){.tools{grid-template-columns:1fr 1fr}}@media(max-width:560px){.tools,.detail{grid-template-columns:1fr}.detail img{max-height:55vh}.actions p{flex-basis:100%}}
]=],
    js = [=[
"use strict";
(() => {
    const data = JSON.parse(document.getElementById("manifest").textContent);
    const byId = id => document.getElementById(id);
    const search = byId("search"), column = byId("column"), value = byId("value"), sort = byId("sort");
    const grid = byId("grid"), count = byId("count"), modal = byId("detail");
    const faces = new Map(); let matches = [], limit = 96, active = 0, trigger = null;
    const make = (tag, text) => { const el = document.createElement(tag); if (text !== undefined) el.textContent = text; return el; };
    const option = (text, key) => { const el = make("option", text); el.value = key; return el; };
    const faceFor = card => { const wanted = faces.get(card.row) || "front"; return card[wanted] ? wanted : (card.front ? "front" : "back"); };
    const alternate = card => { faces.set(card.row, faceFor(card) === "front" ? "back" : "front"); };
    const image = (el, card) => {
        el.alt = card.name + " — " + faceFor(card);
        el.src = encodeURIComponent(card[faceFor(card)]);
        el.onerror = () => { el.alt = "Artwork unavailable: " + card.name; el.classList.add("missing"); };
    };
    byId("title").textContent = data.title; document.title = data.title;
    document.documentElement.style.setProperty("--ratio", data.width + " / " + data.height);
    column.append(option("All columns", ""));
    data.columns.forEach((name, i) => column.append(option(name, String(i))));
    const values = () => {
        value.replaceChildren(option("All values", ""));
        if (column.value !== "") {
            const entries = [...new Set(data.cards.map(card => card.values[Number(column.value)]))].sort((a,b) => a.localeCompare(b));
            entries.forEach((text, i) => value.append(option(text === "" ? "(empty)" : text, String(i))));
            value._entries = entries;
        } else value._entries = [];
        value.disabled = column.value === "";
    };
    const details = () => {
        const card = matches[active]; if (!card) return;
        byId("detailTitle").textContent = card.name;
        byId("position").textContent = (active + 1) + " of " + matches.length + " · source row " + card.row;
        image(byId("detailImage"), card);
        byId("detailFlip").disabled = !(card.front && card.back);
        byId("previous").disabled = active === 0; byId("next").disabled = active === matches.length - 1;
        const fields = byId("fields"); fields.replaceChildren();
        data.columns.forEach((name,i) => fields.append(make("dt", name), make("dd", card.values[i])));
    };
    const render = () => {
        grid.replaceChildren();
        count.textContent = matches.length + " of " + data.cards.length + " cards";
        byId("empty").hidden = matches.length !== 0; byId("more").hidden = matches.length <= limit;
        matches.slice(0, limit).forEach((card, i) => {
            const item = make("article"); item.className = "card";
            const view = make("button"); view.className = "art"; view.type = "button";
            view.setAttribute("aria-label", "View " + card.name); view.dataset.row = String(card.row);
            const img = make("img"); img.loading = "lazy"; image(img,card); view.append(img);
            view.addEventListener("click", () => { active = i; trigger = view; details(); modal.showModal(); });
            item.append(view, make("h2", card.name), make("p", "Row " + card.row + " · " + faceFor(card)));
            if (card.front && card.back) {
                const flip = make("button", "Flip card"); flip.className = "flip"; flip.type = "button";
                flip.addEventListener("click", () => { alternate(card); render(); grid.children[i]?.querySelector(".flip")?.focus(); }); item.append(flip);
            }
            grid.append(item);
        });
    };
    const filter = () => {
        limit = 96; const query = search.value.toLocaleLowerCase();
        matches = data.cards.filter(card => {
            const text = [card.name, ...card.values].join("\n").toLocaleLowerCase();
            return text.includes(query) && (column.value === "" || value.value === "" || card.values[Number(column.value)] === value._entries[Number(value.value)]);
        });
        if (sort.value !== "original") matches.sort((a,b) => {
            const n = a.name.localeCompare(b.name, undefined, {numeric:true}) || a.row - b.row;
            return sort.value === "descending" ? -n : n;
        });
        render();
    };
    search.addEventListener("input", filter);
    column.addEventListener("change", () => { values(); filter(); }); value.addEventListener("change", filter); sort.addEventListener("change", filter);
    byId("reset").addEventListener("click", () => { search.value = ""; column.value = ""; sort.value = "original"; values(); filter(); });
    byId("flipAll").disabled = !data.cards.some(card => card.front && card.back);
    byId("flipAll").addEventListener("click", () => { data.cards.forEach(card => { if(card.front && card.back) alternate(card); }); render(); });
    byId("more").addEventListener("click", () => { limit += 96; render(); });
    byId("close").addEventListener("click", () => modal.close());
    modal.addEventListener("close", () => { if(trigger) { const current = trigger.isConnected ? trigger : grid.querySelector('.art[data-row="' + trigger.dataset.row + '"]'); if(current) current.focus(); } });
    byId("previous").addEventListener("click", () => { if(active > 0) {active--; details();} });
    byId("next").addEventListener("click", () => { if(active < matches.length - 1) {active++; details();} });
    byId("detailFlip").addEventListener("click", () => { const card=matches[active]; if(card.front && card.back) {alternate(card); details(); render();} });
    modal.addEventListener("keydown", event => {
        if (event.target.tagName === "INPUT" || event.target.tagName === "SELECT") return;
        if (event.key === "ArrowLeft" && active > 0) { event.preventDefault(); active--; details(); }
        if (event.key === "ArrowRight" && active < matches.length-1) { event.preventDefault(); active++; details(); }
    });
    values(); filter();
})();
]=],
};
