-- Manual settings are stored in the document, rather than editor preferences.
local Options = {};

function Options.html()
    return [=[
<dialog id="manual-options"><form id="manual-options-form">
<h2>Manual Options</h2>
<div class="manual-options-columns"><fieldset><legend>Page Layout</legend>
<label>Page size<select name="preset"><option value="letter">Letter</option><option value="legal">Legal</option><option value="a4">A4</option><option value="a5">A5</option><option value="half-letter">Half Letter</option><option value="custom">Custom</option></select></label>
<label>Display units<select name="units"><option value="mm">Millimeters</option><option value="in">Inches</option></select></label>
<div class="field-pair"><label>Width<input name="width" type="number" min="0.1" step="0.01" required></label><label>Height<input name="height" type="number" min="0.1" step="0.01" required></label></div>
<label>Orientation<select name="orientation"><option value="portrait">Portrait</option><option value="landscape">Landscape</option></select></label>
<div class="field-pair"><label>Inner margin<input name="marginInner" type="number" min="0" step="0.01" required></label><label>Outer margin<input name="marginOuter" type="number" min="0" step="0.01" required></label></div>
<div class="field-pair"><label>Top margin<input name="marginTop" type="number" min="0" step="0.01" required></label><label>Bottom margin<input name="marginBottom" type="number" min="0" step="0.01" required></label></div>
<label>Bleed (all edges)<input name="bleed" type="number" min="0" step="0.01" required></label>
<label class="check-option"><input name="facingPages" type="checkbox"> Facing pages (first page stands alone)</label>
<label>Default text size (pt)<input name="textSize" type="number" min="0.1" step="0.1" required></label>
<label>Basic text style<select name="textStyle" required></select></label>
</fieldset><fieldset><legend>Page Numbers</legend>
<label class="check-option"><input name="pageNumbers" type="checkbox"> Include page numbers</label>
<label>Page-number style<select name="numberStyle" required></select></label>
<div class="field-pair"><label>First number<input name="numberStart" type="number" min="0" step="1" required></label><label>Number format<select name="numberFormat"><option value="decimal">1, 2, 3</option><option value="roman">i, ii, iii</option><option value="ROMAN">I, II, III</option></select></label></div>
<label>Number position<select name="numberPosition"><option value="center">Bottom center</option><option value="left">Bottom left</option><option value="right">Bottom right</option></select></label>
</fieldset><fieldset><legend>Editor and Snapping</legend>
<label>Editor theme<select name="editorTheme"></select></label>
<label>Zoom step (%)<input name="zoomStep" type="number" min="1" max="100" step="1" required></label>
<label class="check-option"><input name="gridVisible" type="checkbox"> Show grid (editor only)</label>
<div class="field-pair"><label>Cell width (mm)<input name="gridX" type="number" min="0.1" step="0.1" required></label><label>Cell height (mm)<input name="gridY" type="number" min="0.1" step="0.1" required></label></div>
<label class="check-option"><input name="autoSnap" type="checkbox"> Automatic snapping</label>
<label class="check-option"><input name="snapGrid" type="checkbox"> Snap to grid</label>
<label class="check-option"><input name="snapPage" type="checkbox"> Snap to page edges and center</label>
<label class="check-option"><input name="snapMargin" type="checkbox"> Snap to margins</label>
<label class="check-option"><input name="snapObjects" type="checkbox"> Snap to other objects</label>
<p>Hold Alt while moving an object to snap temporarily. Shift and Control keep their resize behavior.</p>
</fieldset></div>
<p id="options-error" role="alert"></p><div class="dialog-actions"><button type="button" id="cancel-options">Cancel</button><button type="submit">Apply</button></div>
</form></dialog>
]=];
end

return Options;
