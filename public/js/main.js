/*
 * COPYRIGHT AND LICENSE
 *
 * Copyright (C) 2011, Georgy Bazhukov.
 *
 * This program is free software, you can redistribute it and/or modify it under
 * the terms of the Artistic License version 2.0.
 */

/*******************
*  Special for IE  *
*******************/

document.createElement('header');
document.createElement('nav');
document.createElement('article');
document.createElement('footer');

/* Initial code */

window.onload = function() {
  //adding the event listerner for Mozilla
  if(window.addEventListener) document.addEventListener('DOMMouseScroll', moveObject, false);
  //for IE/OPERA etc
  document.onmousewheel = moveObject;
  
    var containerHeight = $("#body").height();
    $("#body").height(containerHeight - 128);
    
    
    var left = $("nav.vertical").position().left;
    $("nav.vertical").css( 'left', left - 327 );
}

function moveObject(event) {
  var delta = 0;
  if (!event) event = window.event;
  // normalize the delta
  if (event.wheelDelta)
  {
    // IE & Opera
   delta = event.wheelDelta / 120;
  }
  else if (event.detail) // W3C
  {
    delta = -event.detail / 3;
  }
  var currPos=document.getElementById('body').offsetTop;
  //calculating the next position of the object
  currPos=parseInt(currPos)+(delta*10);
  //moving the position of the object
  document.getElementById('body').style.top=currPos+"px";
}


/* Functions */

function hide(id) {
    $('.popup').hide();
    if ( id !== undefined ) {
        var a = document.getElementById(id);
        a.style.display = (a.style.display == 'block' ? 'none' : 'block');
    }
}

function addValue(id, val) {
    var a = document.getElementById(id);
    a.value = Number(a.value) + Number(val);
    return false;
}

/* Check forms */
var elements = new Array();
