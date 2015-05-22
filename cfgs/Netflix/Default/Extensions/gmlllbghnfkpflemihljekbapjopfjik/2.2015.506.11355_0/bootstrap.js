/** @fileoverview Implements _DumpException */


/**
 * Define _DumpException function - the assembler wraps JS code in a try-catch
 * block that calls this.
 * @param {*} e The exception
 */
function _DumpException(e) {
  window.console.log(e.stack);
  throw e;
}

// Stop closure from trying to download a deps.js file.
var CLOSURE_NO_DEPS = true;
