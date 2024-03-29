// Copyright (C) 2021 Humanitarian OpenStreetmap Team

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Humanitarian OpenStreetmap Team
// 1100 13th Street NW Suite 800 Washington, D.C. 20005
// <info@hotosm.org>

const streamReduce = require('json-stream-reduce')
const path = require('path');

var errors  = 0;
var skipped = 0;

streamReduce({
  map: path.join(__dirname, 'filter-map.js'),             //Map function
  file: path.join(__dirname, 'features.geojsonseq'),      //Input file (lines of JSON)
  maxWorkers:32 // The number of cpus you'd like to use
})
.on('reduce', function(res) {
  skipped += res[0]
  errors  += res[1]
})
.on('end', function() {
  console.error("Finished - skipped " + skipped + " features with " + errors + " errors");
});
