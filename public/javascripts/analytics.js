Raphael.el.isAbsolute = true;
Raphael.el.absolutely = function () {
    this.isAbsolute = 1;
    return this;
};
Raphael.el.relatively = function () {
    this.isAbsolute = 0;
    return this;
};
Raphael.el.moveTo = function (x, y) {
    this._last = {x: x, y: y};
    return this.attr({path: this.attrs.path + ["m", "M"][+this.isAbsolute] + parseFloat(x) + " " + parseFloat(y)});
};
Raphael.el.lineTo = function (x, y) {
    this._last = {x: x, y: y};
    return this.attr({path: this.attrs.path + ["l", "L"][+this.isAbsolute] + parseFloat(x) + " " + parseFloat(y)});
};
Raphael.el.cplineTo = function (x, y, w) {
    this.attr({path: this.attrs.path + ["C", this._last.x + w, this._last.y, x - w, y, x, y]});
    this._last = {x: x, y: y};
    return this;
};

Raphael.fn.drawGrid = function (x, y, w, h, wv, hv, color) {
    color = color || "#000";
    var path = ["M", x, y, "L", x + w, y, x + w, y + h, x, y + h, x, y],
        rowHeight = h / hv,
        columnWidth = w / wv;
    for (var i = 1; i < hv; i++) {
        path = path.concat(["M", x, y + i * rowHeight, "L", x + w, y + i * rowHeight]);
    }
    for (var i = 1; i < wv; i++) {
        path = path.concat(["M", x + i * columnWidth, y, "L", x + i * columnWidth, y + h]);
    }
    return this.path(path.join(",")).attr({stroke: color});
};

function drawMonthChart(holder_div, labels, data) {
  // Draw
  var width = 870,
      height = 220,
      leftgutter = 0,
      bottomgutter = 20,
      topgutter = 20,
      color = "#000099",
      r = Raphael(holder_div, width, height),
      txt = {fill: "#222"},
      X = (width - leftgutter) / labels.length,
      max = Math.max.apply(Math, data),
      Y = (height - bottomgutter - topgutter) / max;

  r.drawGrid(leftgutter + X * .5, topgutter, width - leftgutter - X, height - topgutter - bottomgutter, 10, 10, "#ccc");

  var path = r.path().attr({stroke: color, "stroke-width": 4, "stroke-linejoin": "round"}),
      bgp = r.path().attr({stroke: "none", opacity: .3, fill: color}).moveTo(leftgutter + X * .5, height - bottomgutter),
      frame = r.rect(10, 10, 100, 24, 5).attr({fill: "#D3D3D7", stroke: "#A6A8AE", "stroke-width": 2}).hide(),
      label = [],
      is_label_visible = false,
      leave_timer,
      blanket = r.set();

  label[0] = r.text(60, 10, "24 exceptions").attr(txt).hide();
  for (var i = 0, ii = labels.length; i < ii; i++) {
    var y = Math.round(height - bottomgutter - Y * data[i]),
        x = Math.round(leftgutter + X * (i + .5)),
        t = r.text(x, height - 6, labels[i]).attr(txt).toBack();
    bgp[i == 0 ? "lineTo" : "cplineTo"](x, y, 10);
    path[i == 0 ? "moveTo" : "cplineTo"](x, y, 10);
    var dot = r.circle(x, y, 4).attr({fill: color, stroke: "#009"});
    blanket.push(r.rect(leftgutter + X * i, 0, X, height - bottomgutter).attr({stroke: "none", fill: "#fff", opacity: 0}));
    var rect = blanket[blanket.length - 1];
    (function (x, y, data, lbl, dot) {
      var timer, i = 0;
      $(rect.node).hover(function () {
          clearTimeout(leave_timer);
          var newcoord = {x: +x + 7.5, y: y - 19};
          if (newcoord.x + 100 > width) {
              newcoord.x -= 114;
          }
          frame.show().animate({x: newcoord.x, y: newcoord.y}, 200 * is_label_visible);
          label[0].attr({text: data + " exception" + ((data % 10 == 1) ? "" : "s")}).show().animateWith(frame, {x: +newcoord.x + 50, y: +newcoord.y + 12}, 200 * is_label_visible);
          dot.attr("r", 7);
          is_label_visible = true;
      }, function () {
          dot.attr("r", 5);
          leave_timer = setTimeout(function () {
            frame.hide();
            label[0].hide();
            is_label_visible = false;
          }, 1);
      });
    })(x, y, data[i], labels[i], dot);
  }
  bgp.lineTo(x, height - bottomgutter);
  frame.toFront();
  label[0].toFront();
  blanket.toFront();
};
