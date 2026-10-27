// Remove notification-style overlays from documents and shadow trees.
(() => {
    const selector = '[id^="note-"]';
    const observedRoots = new WeakSet();

    const inspect = node => {
        if (node.nodeType !== Node.ELEMENT_NODE) return;
        if (node.matches(selector)) {
            node.remove();
            return;
        }
        if (node.shadowRoot) observeRoot(node.shadowRoot);
        node.querySelectorAll('*').forEach(element => {
            if (element.matches(selector)) element.remove();
            else if (element.shadowRoot) observeRoot(element.shadowRoot);
        });
    };

    const observeRoot = root => {
        if (observedRoots.has(root)) return;
        observedRoots.add(root);
        new MutationObserver(records => {
            for (const record of records) {
                if (record.type === 'attributes') inspect(record.target);
                else record.addedNodes.forEach(inspect);
            }
        }).observe(root, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['id']
        });
        Array.from(root.children).forEach(inspect);
    };

    // Must run in the page world, before provider scripts. Closed roots cannot
    // be discovered via element.shadowRoot; retain the root returned here.
    const attachShadow = Element.prototype.attachShadow;
    Element.prototype.attachShadow = function (...args) {
        const root = Reflect.apply(attachShadow, this, args);
        observeRoot(root);
        return root;
    };

    observeRoot(document);
    // Discover open roots attached through a constructor cached before injection.
    setInterval(() => inspect(document.documentElement || document), 1000);
})();
