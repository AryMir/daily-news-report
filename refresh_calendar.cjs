const fs = require('fs');
const path = require('path');
const vm = require('vm');
const {createRequire} = require('module');
const source = 'C:\\Antigravity\\Next_Week_Schedule\\generate_report.js';
const originalProject = 'C:\\Antigravity\\Daily_News_Project';
const localRequire = createRequire(source);
let saved = false;
const redirectedFs = new Proxy(fs, {
  get(object, key) {
    if(key === 'readFileSync') return (filename, ...args) => {
      const target = filename === path.join(originalProject,'config.json') ? path.join(__dirname,'config.json') : filename;
      return fs.readFileSync(target,...args);
    };
    if(key === 'writeFileSync') return (filename, data) => {
      if(filename !== path.join(originalProject,'calendar_data.json')) throw Error('Unexpected calendar write blocked');
      JSON.parse(data);
      fs.writeFileSync(path.join(__dirname,'calendar_data.json'),data);
      saved = true;
      console.log('Calendar data refreshed successfully.');
    };
    return object[key];
  }
});
vm.runInNewContext(fs.readFileSync(source,'utf8'), {
  require: name => name === 'fs' ? redirectedFs : localRequire(name),
  console: {log:()=>{},error:()=>console.error('Calendar refresh failed; private details suppressed.')},
  process: {exit: code => {process.exitCode = code;}},
  setTimeout, clearTimeout, Buffer
}, {filename:source});
process.on('beforeExit',()=>{if(!saved) process.exitCode=1;});
