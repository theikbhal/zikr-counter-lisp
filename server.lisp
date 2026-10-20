(ql:quickload :hunchentoot)

(defparameter *db-path*
  "/Users/ikbhal/Desktop/lisp_space/zikr-counter/zikr.db")

(defparameter *web-server*
  (make-instance 'hunchentoot:easy-acceptor
                 :port 8080
                 :address "127.0.0.1"))

(defun db (sql)
  (uiop:run-program
   (list "sqlite3" "-json" *db-path* sql)
   :output :string
   :error-output :string))

(defun sql-text (value)
  (with-output-to-string (out)
    (write-char #\' out)
    (loop for ch across value do
      (when (char= ch #\')
        (write-char #\' out))
      (write-char ch out))
    (write-char #\' out)))

(defun valid-int (value &optional (minimum 0))
  (let ((n (and value
                (ignore-errors (parse-integer value :junk-allowed nil)))))
    (and n (<= minimum n 1000000000) n)))

(defun json-out (sql)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (db sql))

(hunchentoot:define-easy-handler (api-counters :uri "/api/counters") ()
  (json-out
   "SELECT id,name,count,goal,position FROM counters ORDER BY position,id;"))

(hunchentoot:define-easy-handler (api-add :uri "/api/add")
    (name goal)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (let ((n (and name (string-trim '(#\Space #\Tab) name)))
        (g (valid-int goal 1)))
    (if (and n (plusp (length n)) (<= (length n) 100) g)
        (progn
          (db (format nil
               "INSERT INTO counters(name,count,goal,position) VALUES(~a,0,~d,COALESCE((SELECT MAX(position)+1 FROM counters),0));"
               (sql-text n) g))
          "{\"ok\":true}")
        (progn
            (setf (hunchentoot:return-code*) 400)
            "{\"ok\":false}"))))

(hunchentoot:define-easy-handler (api-edit :uri "/api/edit")
    (id name goal)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (let ((i (valid-int id 1))
        (n (and name (string-trim '(#\Space #\Tab) name)))
        (g (valid-int goal 1)))
    (if (and i n (plusp (length n)) (<= (length n) 100) g)
        (progn
          (db (format nil
               "UPDATE counters SET name=~a,goal=~d,updated_at=CURRENT_TIMESTAMP WHERE id=~d;"
               (sql-text n) g i))
          "{\"ok\":true}")
        "{\"ok\":false}")))

(hunchentoot:define-easy-handler (api-increment :uri "/api/increment")
    (id)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (let ((i (valid-int id 1)))
    (if i
        (progn
          (db (format nil
               "UPDATE counters SET count=count+1,updated_at=CURRENT_TIMESTAMP WHERE id=~d;" i))
          "{\"ok\":true}")
        "{\"ok\":false}")))

(hunchentoot:define-easy-handler (api-reset :uri "/api/reset") (id)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (let ((i (valid-int id 1)))
    (if i
        (progn
          (db (format nil
               "UPDATE counters SET count=0,updated_at=CURRENT_TIMESTAMP WHERE id=~d;" i))
          "{\"ok\":true}")
        "{\"ok\":false}")))

(hunchentoot:define-easy-handler (api-delete :uri "/api/delete") (id)
  (setf (hunchentoot:content-type*) "application/json; charset=utf-8")
  (let ((i (valid-int id 1)))
    (if i
        (progn
          (db (format nil "DELETE FROM counters WHERE id=~d;" i))
          "{\"ok\":true}")
        "{\"ok\":false}")))



;; Serve the dashboard HTML file
(hunchentoot:define-easy-handler (home :uri "/") ()
  (setf (hunchentoot:content-type*) "text/html; charset=utf-8")
  (with-open-file (file
                   "/Users/ikbhal/Desktop/lisp_space/zikr-counter/dashboard.html"
                   :direction :input)
    (let ((contents (make-string (file-length file))))
      (read-sequence contents file)
      contents)))

;; Serve the dashboard JavaScript file
(hunchentoot:define-easy-handler (dashboard-js :uri "/dashboard.js") ()
  (setf (hunchentoot:content-type*) "application/javascript; charset=utf-8")
  (with-open-file (file
                   "/Users/ikbhal/Desktop/lisp_space/zikr-counter/dashboard.js"
                   :direction :input)
    (let ((contents (make-string (file-length file))))
      (read-sequence contents file)
      contents)))



;; Start the web server
(hunchentoot:start *web-server*)

(format t "~%Allah Zikr Counter server started at http://127.0.0.1:8080/~%")