(ql:quickload :hunchentoot)

(defparameter *web-server*
  (make-instance 'hunchentoot:easy-acceptor
                 :port 8080
                 :address "127.0.0.1"))

(hunchentoot:define-easy-handler (home :uri "/") ()
  (setf (hunchentoot:content-type*) "text/html; charset=utf-8")
  "<!doctype html>
<html lang='en'>
<head>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<title>Allah Zikr Counter</title>
<style>
body{font-family:system-ui,sans-serif;max-width:520px;margin:30px auto;padding:20px;background:#f5f7f2;color:#183b2b}
main{background:white;padding:24px;border-radius:20px;text-align:center}
.count{font-size:64px;font-weight:bold;margin:20px}
button,select{font:inherit;padding:13px;border-radius:12px;margin:5px;cursor:pointer}
#add{background:#176b48;color:white;font-size:22px}
progress{width:100%;height:18px;accent-color:#176b48}
</style>
</head>
<body><main>
<h1>Allah Zikr Counter</h1>
<p>Begin with Bismillah</p>
<label for='target'>Target: </label>
<select id='target'>
<option>33</option><option>100</option><option>313</option><option selected>1000</option>
</select>
<div class='count' id='count'>0</div>
<button id='add'>+1 Zikr</button>
<button id='reset'>Reset</button>
<progress id='progress' value='0' max='1000'></progress>
<p id='status'>0 of 1000 completed</p>
<p>Your count is saved in this browser on this Mac.</p>
</main>
<script>
let count=Number(localStorage.getItem('zikr-count')||0);
const target=document.getElementById('target');
target.value=localStorage.getItem('zikr-target')||'1000';
function render(){
 const goal=Number(target.value);
 document.getElementById('count').textContent=count;
 document.getElementById('progress').max=goal;
 document.getElementById('progress').value=Math.min(count,goal);
 document.getElementById('status').textContent=count+' of '+goal+' completed'+(count>=goal?' — Alhamdulillah!':'');
 localStorage.setItem('zikr-count',String(count));
 localStorage.setItem('zikr-target',String(goal));
}
document.getElementById('add').onclick=()=>{count++;render()};
document.getElementById('reset').onclick=()=>{if(confirm('Reset count to zero?')){count=0;render()}};
target.onchange=render;
render();
</script>
</body></html>")

(hunchentoot:start *web-server*)
(format t "~%Zikr Counter running at http://127.0.0.1:8080~%")
