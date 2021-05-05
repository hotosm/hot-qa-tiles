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

// Filter script (original logic by Tom Lee) to test out more 'compact' tilesets

const readline = require('readline');
const area = require('@turf/area').default;

const rl = readline.createInterface({
  input: process.stdin
});

var invalid = 0;
var feat
var linesProcessed = 0;

rl.on('line', (input) => {
  try{

    //Starts with a record separator?
    if (input.startsWith("\x1e")){
      feat = JSON.parse(input.substring(1,input.length))
    }
    
    //Or if it's part of a feature collection
    else if (input.endsWith(",") ){ 
      feat = JSON.parse(input.substring(0, input.length-1));
    
    }else{
      feat = JSON.parse(input.trim())
    }
      
  }catch(e){
    invalid++;
    return;
    //throw e  
  }
  
  linesProcessed++
  if (linesProcessed%10000==0){
    process.stderr.write("\r"+(linesProcessed/1000000).toFixed(2)+"M lines processed | "+invalid + " parsing error(s)") 
  }
    
  //First: if it's a coastline or has an admin_level <2, skip it
  if (feat.properties && ((feat.properties.natural === 'coastline') || parseInt(feat.properties.admin_level || 9) < 2)){
    return
  
  //Second, throw out all polygons that are greater than 25 km^2
  }else if (feat.geometry && (
      (feat.geometry.type === 'Polygon') || (feat.geometry.type === 'MultiPolygon')) && area(feat) > 6.475E7){      
     return

  //Could do more here if desired

  //write input to stdout
  }else{
    process.stdout.write(input + '\n');
  }   
});
