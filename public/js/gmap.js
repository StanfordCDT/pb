// a wrapper object for a Google Maps object in the map
function GMapGeometry(map, title, g, opts) {
  var c = g.coordinates;
  if (typeof opts === 'undefined')
    opts = {};

  if (g.type == 'Point') {
    this.gmapObject = new google.maps.Marker($.extend({
      position: new google.maps.LatLng(c[0], c[1]),
      map: map
    }, opts));
  } else if (g.type == 'LineString') {
    var path = [];
    for (var i = 0; i < c.length; ++i)
      path.push( new google.maps.LatLng(c[i][0], c[i][1]) );
    this.gmapObject = new google.maps.Polyline($.extend({
      path: path,
      strokeColor: '#428bca',
      strokeOpacity: 1,
      strokeWeight: 6,
      map: map
    }, opts));
  } else if (g.type == 'Polygon') {
    //var r = c[0]; // the exterior ring
    var r = c;
    var path = [];
    for (var i = 0; i < r.length; ++i)
      path.push( new google.maps.LatLng(r[i][0], r[i][1]) );
    this.gmapObject = new google.maps.Polygon($.extend({
      path: path,
      strokeColor: '#428bca',
      strokeOpacity: 1,
      strokeWeight: 2,
      map: map
    }, opts));
  }

  this.center = function() {
    if (g.type == 'Point') {
      return new google.maps.LatLng(c[0], c[1]);
    } else if (g.type == 'LineString') {
      return new google.maps.LatLng(c[c.length-1][0], (c[0][1]+c[1][1])/2);
    } else if (g.type == 'Polygon') {
      var bounds = new google.maps.LatLngBounds();
      for (var i = 0; i < c.length; i++) {
        bounds.extend(new google.maps.LatLng(c[i][0], c[i][1]));
      }
      return bounds.getCenter();
    }
  }
  this.isMarker = (g.type == 'Point');
  this.title = title;
}

// Maps for projects that have adjustable costs
function GMap(id, info_id, data, zoom, templates, mapOpts) {
  var obj = this;
  var streets = {
    street_resurfacing: [],
    alley_resurfacing: [],
    apron_resurfacing: [],
    sidewalk_repairing: []
  };
  if (typeof mapOpts === 'undefined')
    mapOpts = {};
  var currentCost = 0;

  function initialize() {
    var mapOptions = $.extend({
      center: new google.maps.LatLng(data.ward_center[0], data.ward_center[1]),
      minZoom: 6,
      zoom: zoom ? zoom : 14,
      panControl: false,
      streetViewControl: false,
      mapTypeControl: false,
      scrollwheel: false,
      fullscreenControl: false
    }, mapOpts);

    var map = new google.maps.Map(document.getElementById(id), mapOptions);
    obj.map = map;

    var styles = [
  //     {
  //       stylers: [
  //         { saturation: -20 }
  //       ]
  //     },
      {
        featureType: "road",
        elementType: "geometry",
        stylers: [
  //        { lightness: 100 },
          { visibility: "simplified" }
        ]
      },
      {
        "featureType": "water",
        "stylers": [
          { "color": "#ffffff" },
        ]
      }
    ];
    map.setOptions({styles: styles});

    var highlightedStreet = null;
    var highlightStreet = function (s) {
      unhighlightStreet();
      s.setOptions({strokeOpacity: 0.6});
      highlightedStreet = s;
    }
    var unhighlightStreet = function () {
      if (highlightedStreet) {
        highlightedStreet.setOptions({strokeOpacity: 1});
        highlightedStreet = null;
      }
    }

    var infowindow = new google.maps.InfoWindow();
    google.maps.event.addListener(map, 'mouseout', function() {
      infowindow.close();
      unhighlightStreet();
    });
    google.maps.event.addListener(map, 'mousemove', function() {
      infowindow.close();
      unhighlightStreet();
    });
    google.maps.event.addListener(map.getStreetView(), 'visible_changed', function() {
      //$('#resurfaced').css('display', map.getStreetView().getVisible() ? 'none' : 'block');
    });

    var addMouseOverListener = function(gmapgeometry) {
      google.maps.event.addListener(gmapgeometry.gmapObject, 'mouseover', function() {
        infowindow.setOptions({
          content: gmapgeometry.title,
          position: gmapgeometry.center(),
        });
        if (gmapgeometry.isMarker) {
          infowindow.open(map, gmapgeometry.gmapObject);
        } else {
          infowindow.open(map);
          highlightStreet(gmapgeometry.gmapObject);
        }
      });
    };

    for (var i = 0; i < data.street_resurfacing.length; ++i) {
      var sr = data.street_resurfacing[i];
      var o = new GMapGeometry(map, sr[0], sr[1], {strokeColor: '#428bca', visible: false});
      addMouseOverListener(o);
      streets.street_resurfacing.push(o);
    }
    for (var i = 0; i < data.alley_resurfacing.length; ++i) {
      var sr = data.alley_resurfacing[i];
      var o = new GMapGeometry(map, sr[0], sr[1], {strokeColor: '#f08000', visible: false});
      addMouseOverListener(o);
      streets.alley_resurfacing.push(o);
    }
    for (var i = 0; i < data.apron_resurfacing.length; ++i) {
      var sr = data.apron_resurfacing[i];
      var o = new GMapGeometry(map, sr[0], sr[1], {strokeColor: '#5f0016', icon: "https://maps.google.com/mapfiles/ms/icons/red-dot.png", visible: false});
      addMouseOverListener(o);
      streets.apron_resurfacing.push(o);
    }
    for (var i = 0; i < data.sidewalk_repairing.length; ++i) {
      var sr = data.sidewalk_repairing[i];
      var o = new GMapGeometry(map, sr[0], sr[1], {strokeColor: '#005c25', icon: "https://maps.google.com/mapfiles/ms/icons/blue-dot.png", visible: false});
      addMouseOverListener(o);
      streets.sidewalk_repairing.push(o);
    }

    var wardBorder = data.ward_border;
    if (wardBorder) {
      var outerPath = [
        new google.maps.LatLng(50, -130),
        new google.maps.LatLng(50, -60),
        new google.maps.LatLng(20, -60),
        new google.maps.LatLng(20, -130)
      ];
      var path = [];
      for (var i = 0; i < wardBorder.length; ++i) {
        var c = wardBorder[i];
        path.push(new google.maps.LatLng(c[0], c[1]));
      }
      new google.maps.Polyline({
        path: path,
        strokeColor: '#666666',
        strokeOpacity: 1,
        strokeWeight: 2,
        clickable: false,
        map: map
      });
      new google.maps.Polygon({
        paths: [outerPath, path],
        strokeWeight: 0,
        fillColor: '#ffffff',
        fillOpacity: 0.5,
        clickable: false,
        map: map
      });
    }

    if (currentCost != 0)
      obj.renderMap(currentCost);
  }


  this.renderMap = function(cost) {
    currentCost = cost;
    var ci = Math.round(cost / 100000); // FIXME: Use cost_step.
    var n_street_resurfacing = data.n_street_resurfacing[ci];
    var n_alley_resurfacing = data.n_alley_resurfacing[ci];
    var n_apron_resurfacing = data.n_apron_resurfacing[ci];
    var n_sidewalk_repairing = data.n_sidewalk_repairing[ci];
    var custom_text = data.custom_text ? data.custom_text[ci] : null;

    // update objects' visibility
    if (obj.map) {
      if (cost > 0) {
        google.maps.event.trigger(obj.map, 'resize');
        obj.map.setCenter(new google.maps.LatLng(data.ward_center[0], data.ward_center[1]));
        obj.map.setZoom(zoom ? zoom : 14);
      }
      for (var k = 0; k < data.street_resurfacing.length; ++k) {
        streets.street_resurfacing[k].gmapObject.setOptions({visible: k < n_street_resurfacing});
      }
      for (var k = 0; k < data.alley_resurfacing.length; ++k) {
        streets.alley_resurfacing[k].gmapObject.setOptions({visible: k < n_alley_resurfacing});
      }
      for (var k = 0; k < data.apron_resurfacing.length; ++k) {
        streets.apron_resurfacing[k].gmapObject.setOptions({visible: k < n_apron_resurfacing});
      }
      for (var k = 0; k < data.sidewalk_repairing.length; ++k) {
        streets.sidewalk_repairing[k].gmapObject.setOptions({visible: k < n_sidewalk_repairing});
      }
    }

    // update the info text
    if (templates == null)
      return;
    var template = function(singular, plural, count) {
      return ((count == 1) ? singular : plural).replace("%{count}", count);
    };
    var lines = [];
    if (n_street_resurfacing){
      lines.push("<img src='/img/map_street_resurfacing.png' style='vertical-align: middle;' /> " +
        template(templates.street_resurfacing_count.one,
        templates.street_resurfacing_count.other, n_street_resurfacing));
    }
    if (n_alley_resurfacing) {
      lines.push("<img src='/img/map_alley_resurfacing.png' style='vertical-align: middle;' /> " +
        template(templates.alley_resurfacing_count.one,
        templates.alley_resurfacing_count.other, n_alley_resurfacing));
    }
    if (n_apron_resurfacing) {
      lines.push("<img src='/img/map_apron_resurfacing.png' style='vertical-align: middle;' /> " +
        template(templates.apron_resurfacing_count.one,
        templates.apron_resurfacing_count.other, n_apron_resurfacing));
    }
    if (n_sidewalk_repairing && (data.shows_sidewalk_text === undefined || !!data.shows_sidewalk_text)) {
      lines.push("<img src='/img/map_sidewalk_repairing.png' style='vertical-align: middle;' /> " +
        template(templates.sidewalk_repairing_count.one,
        templates.sidewalk_repairing_count.other, n_sidewalk_repairing));
    }
    if (!!custom_text) {
      lines.push(custom_text);
    }
    var html;
    if (lines.length > 0) {
      html = lines.join("<br>");
    } else {
      html = "No streets resurfaced";
    }
    document.getElementById(info_id).innerHTML = html;
  }


  //google.maps.event.addDomListener(window, 'load', initialize);
  initialize();
}


// Maps for projects that have fixed costs
// Embed a Google Map given the id and location of the project
function drawMap(id, objects) {
  // Use some default lattitude and longitude
  var map_center = new google.maps.LatLng(41.8337329, -87.7321555);

  // Declare the map options
  var mapCanvas = document.getElementById(id);
  var mapOptions = {
    center: map_center,
    zoom: 14,
    panControl: false,
    streetViewControl: false,
    mapTypeControl: false,
    scrollwheel: false,
    fullscreenControl: false
  }

  // Declare the Google Map style
  var mapStyles = [
    {
      featureType: "road",
      elementType: "geometry",
      stylers: [
        { visibility: "simplified" }
      ]
    }
  ];

  // Declare a Google map
  var map = new google.maps.Map(mapCanvas, mapOptions);
  map.setOptions({styles: mapStyles});

  // Reduce the zoom
  if (objects.length > 1)
    map.setZoom(13);

  var markerBounds = new google.maps.LatLngBounds();

  // Plot markers at all the locations
  for (var i = 0; i < objects.length; i++) {
    var object = objects[i];
    if ($.isArray(object)) {
      var coordinates = object;
      var markerLocation = new google.maps.LatLng(coordinates[0], coordinates[1]);
      new google.maps.Marker({
        map: map,
        position: markerLocation
      });
      markerBounds.extend(markerLocation);
    } else {
      var o = new GMapGeometry(map, null, object, {});
      markerBounds.extend(o.center());
    }
  }

  // Center the map at the center of the locations
  map.setCenter(markerBounds.getCenter());
}
