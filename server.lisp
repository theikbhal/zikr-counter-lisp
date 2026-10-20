(ql:quickload :hunchentoot)

(defparameter *db-path*
  "/Users/ikbhal/Desktop/lisp_space/zikr-counter/zikr.db")

(defparameter *web-server*
  (make-instance 'hunchentoot:easy-acceptor
                 :port 8080
                 :address "127.0.0.1"))

(defun sqlite-query (sql)
  (string-trim '(#\Space #\Tab #\Newline #\Return)
    (uiop:run-program
      (list "sqlite3" "-noheader" *db-path* sql)
      :output :string
      :error-output :string)))

(defun today-state ()
  (let* ((result
           (sqlite-query
             "INSERT OR IGNORE INTO zikr_sessions (zikr_date, zikr_name, count, target) VALUES (date('now','localtime'), 'Allah Zikr', 0, 1000); SELECT count || '|' || target FROM zikr_sessions WHERE zikr_date = date('now','localtime') AND zikr_name = 'Allah Zikr';"))
         (separator (position #\| result)))
    (if separator
        (values
          (parse-integer (subseq result 0 separator))
          (parse-integer (subseq result (1+ separator))))
        (values 0 1000))))

(hunchentoot:define-easy-handler (api-state :uri "/api/state") ()
  (setf (hunchentoot:content-type*) "application/json")
  (multiple-value-bind (count target) (today-state)
    (format nil "{\"count\":~d,\"target\":~d}" count target)))

(hunchentoot:define-easy-handler (api-save :uri "/api/save")
    (count target)
  (setf (hunchentoot:content-type*) "application/json")
  (let* ((new-count (ignore-errors (parse-integer count)))
         (new-target (ignore-errors (parse-integer target))))
    (if (and new-count
             (<= 0 new-count 1000000000)
             (member new-target '(33 100 313 1000)))
        (progn
          (sqlite-query
            (format nil
              "INSERT INTO zikr_sessions (zikr_date, zikr_name, count, target) VALUES (date('now','localtime'), 'Allah Zikr', ~d, ~d) ON CONFLICT(zikr_date, zikr_name) DO UPDATE SET count = excluded.count, target = excluded.target, updated_at = CURRENT_TIMESTAMP;"
              new-count new-target))
          "{\"ok\":true}")
        (progn
          (setf (hunchentoot:return-code*) 400)
          "{\"ok\":false}"))))

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
<option value='33'>33</option>
<option value='100'>100</option>
<option value='313'>313</option>
<option value='1000' selected>1000</option>
</select>
<div class='count' id='count'>0</div>
<button id='add'>+1 Zikr</button>
<button id='reset'>Reset</button>
<progress id='progress' value='0' max='1000'></progress>
<p id='status'>Loading count...</p>
<p id='sync'>Connecting to SQLite...</p>
</main>
<script>
let count=0;
let saving=Promise.resolve();
const target=document.getElementById('target');

function render(){
 const goal=Number(target.value);
 document.getElementById('count').textContent=count;
 document.getElementById('progress').max=goal;
 document.getElementById('progress').value=Math.min(count,goal);
 document.getElementById('status').textContent=
   count+' of '+goal+' completed'+(count>=goal?' — Alhamdulillah!':'');
}

function persist(){
 const savedCount=count;
 const savedTarget=Number(target.value);
 saving=saving.then(()=>fetch('/api/save',{
   method:'POST',
   headers:{'Content-Type':'application/x-www-form-urlencoded'},
   body:'count='+savedCount+'&target='+savedTarget
 })).then(response=>{
   if(!response.ok) throw Error('Save failed');
   document.getElementById('sync').textContent='Saved in SQLite';
 }).catch(()=>{
   document.getElementById('sync').textContent='Save failed — check server';
 });
}

document.getElementById('add').onclick=()=>{
 count++;
 render();
 persist();
};

document.getElementById('reset').onclick=()=>{
 if(confirm('Reset count to zero?')){
   count=0;
   render();
   persist();
 }
};

target.onchange=()=>{
 render();
 persist();
};

fetch('/api/state').then(response=>{
 if(!response.ok) throw Error('Load failed');
 return response.json();
}).then(state=>{
 count=state.count;
 target.value=String(state.target);
 render();
 document.getElementById('sync').textContent='Loaded from SQLite';
}).catch(()=>{
 document.getElementById('status').textContent='Could not load count';
 document.getElementById('sync').textContent='Check the server and database';
});
</script>
</body>
</html>")

(hunchentoot:start *web-server*)
(format t "~%Zikr Counter running at http://127.0.0.1:8080~%")
