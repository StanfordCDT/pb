function extendObj(obj1, obj2){
    for (var key in obj2){
        if(obj2.hasOwnProperty(key)){
            obj1[key] = obj2[key];
        }
    }

    return obj1;
}
// a wrapper object for a Google Maps object in the map
function GMapGeometry(map, title, g, opts) {
  var c = g.coordinates;
  if (typeof opts === 'undefined')
    opts = {};

  
  if (g.type == 'Point') {
    this.gmapObject = L.marker(new L.latLng(c[0], c[1]),opts).addTo(map);
  } else if (g.type == 'LineString') {
    var path = [];
    for (var i = 0; i < c.length; ++i)
      path.push( new L.latLng(c[i][0], c[i][1]) );
    this.gmapObject = L.polyline(path,extendObj({color:'#428bca',weight:6,opacity:1},opts)).addTo(map);
  } else if (g.type == 'Polygon') {
    //var r = c[0]; // the exterior ring
    var r = c;
    var path = [];
    for (var i = 0; i < r.length; ++i)
      path.push( new L.latLng(r[i][0], r[i][1]) );
    this.gmapObject = L.polygon(path,extendObj({color:'#428bca',weight:2,opacity:1},opts)).addTo(map);
      
  }




  this.center = function() {
    if (g.type == 'Point') {
      return new L.latLng(c[0], c[1]);
    } else if (g.type == 'LineString') {
      return new L.latLng(c[c.length-1][0], (c[0][1]+c[1][1])/2);
    } else if (g.type == 'Polygon') {
      var bounds = new L.latLngBounds();
      for (var i = 0; i < c.length; i++) {
        bounds.extend(new L.latLng(c[i][0], c[i][1]));
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

 

  let description = L.control({position: "topright"});

  description.onAdd = function() {
        this._div = L.DomUtil.create("div", "description");
        //div.innerHTML = html;
        return this._div;
  };

  description.update = function(html){
      this._div.innerHTML = html;
  }

  var timeout = 0;


  function initialize() {

   
    var styles = [
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

    var mapOptions = extendObj({
      center: new L.latLng(data.ward_center[0], data.ward_center[1]),
      minZoom: 6,
      zoom: zoom ? zoom : 14,
      scrollwheelZoom: false
    }, mapOpts);

    

    var map = new L.map(document.getElementById(id), mapOptions);

    

    L.tileLayer('http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: 'Map data &copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors',
      //styles:mapStyles,
      //maxZoom: 18,
    }).addTo(map);

    
    obj.map = map;
    //map.setOptions({styles: styles});

    var highlightedStreet = null;
    var highlightStreet = function (s) {
      unhighlightStreet();
      s.setStyle({Opacity: 0.6});
      highlightedStreet = s;
    };
    
    var unhighlightStreet = function () {
      if (highlightedStreet) {
        highlightedStreet.setStyle({Opacity: 1});
        highlightedStreet = null;
      }
    };

    


    map.on("mouseout",function(){
        map.closePopup();
        unhighlightStreet();
    });

    
    map.on("mousemove",function(){
        
        if (timeout < 50){
          timeout = timeout +1;
        }
        else{
          map.closePopup();
          unhighlightStreet();
          timeout = 0;

        }

        


        
    });

    function runScript(e){
        map.closePopup();
        unhighlightStreet();  
    };

    

    var addMouseOverListener = function(gmapgeometry) {
      

      gmapgeometry.gmapObject.on("mouseover",function(){

          gmapgeometry.gmapObject.bindPopup(gmapgeometry.title);

          if (map.hasLayer(gmapgeometry.gmapObject)){

              gmapgeometry.gmapObject.openPopup(); //does not matter as popup can be attached to marker or path
          }

      });

    };

    for (var i = 0; i < data.street_resurfacing.length; ++i) {
      var sr = data.street_resurfacing[i];
      var o = new GMapGeometry(map, sr[0], sr[1], {color: '#428bca'}); //remove visibility to false
      map.removeLayer(o.gmapObject); //setting layer to false
      addMouseOverListener(o);
      streets.street_resurfacing.push(o);
    }
    for (var i = 0; i < data.alley_resurfacing.length; ++i) {
      var sr = data.alley_resurfacing[i];
      var o = new GMapGeometry(map, sr[0], sr[1], {color: '#f08000'});//remove visibility to false
      map.removeLayer(o.gmapObject);
      addMouseOverListener(o);
      streets.alley_resurfacing.push(o);
    }
    for (var i = 0; i < data.apron_resurfacing.length; ++i) {
      var sr = data.apron_resurfacing[i];
      var o = new GMapGeometry(map, sr[0], sr[1], {color: '#5f0016', icon: L.icon({iconUrl: "https://maps.google.com/mapfiles/ms/icons/red-dot.png"})}); //removed visibility to false
      map.removeLayer(o.gmapObject);
      addMouseOverListener(o);
      streets.apron_resurfacing.push(o);
    }
    for (var i = 0; i < data.sidewalk_repairing.length; ++i) {
      var sr = data.sidewalk_repairing[i];
      var o = new GMapGeometry(map, sr[0], sr[1], {color: '#005c25', icon: L.icon({iconUrl: "https://maps.google.com/mapfiles/ms/icons/blue-dot.png"})});
      map.removeLayer(o.gmapObject);
      addMouseOverListener(o);
      streets.sidewalk_repairing.push(o);
    }

    var wardBorder = data.ward_border;
    if (wardBorder) {
      var outerPath = [
        new L.latLng(50, -130),
        new L.latLng(50, -60),
        new L.latLng(20, -60),
        new L.latLng(20, -130)
      ];
      var path = [];
      for (var i = 0; i < wardBorder.length; ++i) {
        var c = wardBorder[i];
        path.push(new L.latLng(c[0], c[1]));
      }
      
      console.log(path,outerPath);

      L.polyline(path,{color:'#666666',opacity:1,weight:2}).addTo(map);

      L.polygon([outerPath, path],{weight:0.5,fillColor:'#666666',fillOpacity:0.2}).addTo(map); //adjust color accordingly
    }

    if (currentCost != 0)
      obj.renderMap(currentCost);

    description.addTo(map);
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
        obj.map.panTo(new L.latLng(data.ward_center[0], data.ward_center[1]));
        obj.map.setZoom(zoom ? zoom : 14);
      }
      for (var k = 0; k < data.street_resurfacing.length; ++k) {
        if (k < n_street_resurfacing){
            obj.map.addLayer(streets.street_resurfacing[k].gmapObject);
        }
        else{
            obj.map.removeLayer(streets.street_resurfacing[k].gmapObject);
        }
        
      }
      for (var k = 0; k < data.alley_resurfacing.length; ++k) {
        if (k < n_alley_resurfacing){
          obj.map.addLayer(streets.alley_resurfacing[k].gmapObject);
        }
        else{
          obj.map.removeLayer(streets.alley_resurfacing[k].gmapObject); 
        }
       
      }
      for (var k = 0; k < data.apron_resurfacing.length; ++k) {
        if (k < n_apron_resurfacing){
          obj.map.addLayer(streets.apron_resurfacing[k].gmapObject);
        }
        else{
          obj.map.removeLayer(streets.apron_resurfacing[k].gmapObject);
        }
       
      }
      for (var k = 0; k < data.sidewalk_repairing.length; ++k) {
        if (k < n_sidewalk_repairing){
          obj.map.addLayer(streets.sidewalk_repairing[k].gmapObject);
        }
        else{
          obj.map.removeLayer(streets.sidewalk_repairing[k].gmapObject);
        }
        
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

    description.update(html);

  }

  initialize();
}


// Maps for projects that have fixed costs
// Embed a Google Map given the id and location of the project
function drawMap(id, objects) {
  // Use some default lattitude and longitude
  var map_center = new L.latLng(41.8337329, -87.7321555);



  // Declare the map options
  var mapCanvas = document.getElementById(id);
  
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

  var mapOptions = {
    center: map_center,
    zoom: 14,
    scrollwheelZoom: false
  };


  // Declare a Google map
  var map = new L.map(mapCanvas, mapOptions);

  L.tileLayer('http://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: 'Map data &copy; <a href="https://www.openstreetmap.org/">OpenStreetMap</a> contributors',
  }).addTo(map);


  

  // Reduce the zoom
  if (objects.length > 1)
    map.setZoom(13);

  var markerBounds = new L.latLngBounds();

  

  // Plot markers at all the locations
  for (var i = 0; i < objects.length; i++) {
    var object = objects[i];
    if ($.isArray(object)) {
      var coordinates = object;
      var markerLocation = new L.latLng(coordinates[0], coordinates[1]);
      marker = L.marker(markerLocation).addTo(map);
      
      markerBounds.extend(markerLocation);
    } else {
      var o = new GMapGeometry(map, null, object, {});

      //console.log(o);
      
      markerBounds.extend(o.center());
    }
  }

  
  map.panTo(markerBounds.getCenter()).fitBounds(markerBounds.getCenter().toBounds(500));

  
}
