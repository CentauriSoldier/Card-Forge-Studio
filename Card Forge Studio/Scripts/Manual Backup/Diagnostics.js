/* Publish browser diagnostics for Lua to log outside WebView callbacks. */
(() => {
    "use strict";
    let sequence=0;
    const hex=text=>Array.from(new TextEncoder().encode(text),b=>b.toString(16).padStart(2,'0')).join('');
    function report(error,context='JavaScript',source='',line=0,column=0) {
        const message=error&&error.message?error.message:String(error),stack=error&&error.stack?String(error.stack):'';
        const text=`Manual ${context}: ${message}`+(source?`\nSource: ${source}:${line}:${column}`:'')+(stack?'\n'+stack:'');
        const root=document.documentElement;root.setAttribute('data-cfs-js-error-'+(++sequence),hex(text));root.dataset.cfsJsErrorCount=String(sequence);document.title='CFS Manual JavaScript Error '+sequence;
    }
    window.addEventListener('error',event=>report(event.error||event.message,'JavaScript',event.filename,event.lineno,event.colno));
    window.addEventListener('unhandledrejection',event=>report(event.reason,'unhandled promise rejection'));
    const original=console.error.bind(console);
    console.error=(...values)=>{original(...values);report(values.map(v=>v&&v.stack?v.stack:String(v)).join(' '),'console.error');};
    window.CFSManualDiagnostics={report,run(context,fn){try{fn();return 'OK';}catch(error){report(error,context);return 'ERROR';}}};
})();
