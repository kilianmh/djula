(in-package :djula)

;; --- Utilities ----------------------------------------------------------------

(defun format-translation (string &rest args)
  (apply #'format nil
         (ppcre:regex-replace-all
          "\\:(\\w*)"
          string
          (lambda (_ varname)
            (declare (ignore _))
            (let ((val (access:access args (make-keyword varname))))
              (or (and val (princ-to-string val))
                  (error "~A missing in ~A translation" varname string))))
          :simple-calls t)
         args))

(defun resolve-plist (plist)
  (loop
    :for key :in plist :by #'cddr
    :for val :in (cdr plist) :by #'cddr
    :collect key
    :collect (if (symbolp val)
                 (resolve-variable-phrase
                  (parse-variable-phrase (princ-to-string val)))
                 (princ-to-string val))))

;; --- Generic interface -------------------------------------------------------

(defvar *translation-backends* '()
  "List of available translation backends.")

(defvar *translation-backend* nil
  "The translation backend. One of :locale, :gettext, :translate.
Loading the correspondent Djula ASDF translation backend system is required.")

(defvar *warn-on-untranslated-messages* t)
(defvar *untranslated-messages* nil)

(defun current-translation-backend ()
  (or *translation-backend*
      (car *translation-backends*)))      

(defun translate (string &optional args
                           (language (or *current-language* *default-language*))
                           (backend (current-translation-backend)))
  "Translate STRING using Djula transaltion backend.
LANGUAGE is the language to translate to. The default is to use either *CURRENT-LANGUAGE* or *DEFAULT-LANGUAGE*, in that order.
BACKEND is the translation backend to use. Default is *TRANSLATION-BACKEND*."
  (apply #'backend-translate backend string language args))

(defgeneric backend-translate (backend string language &rest args)
  (:method ((backend null) string language &rest args)
    (declare (ignore language args))
    (warn "Translation backend has not been setup. ~%Load one of Djula's translation backend ASDF systems and set *translation-backend*.")
    string)
  (:method ((backend t) string language &rest args)
    (declare (ignore language args))
    (warn "Invalid translation backend: ~A" backend)
    string))

;;---- Djula tags ---------------------------------------------------------------

;; reading :UNPARSED-TRANSLATION-VARIABLE TOKENS created by {_ translation _}

(def-token-processor :unparsed-translation (unparsed-string) rest
  (multiple-value-bind (key pos) (read-from-string unparsed-string)
    (let ((args (and (< pos (length unparsed-string))
                     (read-from-string (format nil "(~A)"
                                               (subseq unparsed-string pos))))))
      `((:translation
         ,(if (stringp key)
              ;; is a hard-coded string
              key
              ;; we assume it is a variable reference
              (parse-variable-phrase (princ-to-string key)))
         ,@args)
        ,@(process-tokens rest)))))

(def-unparsed-tag-processor :trans (unparsed-string) rest
  (multiple-value-bind (key pos) (read-from-string unparsed-string)
    (let ((args (and (< pos (length unparsed-string))
                     (read-from-string (format nil "(~A)"
                                               (subseq unparsed-string pos))))))
      `((:translation
         ,(if (stringp key)
              ;; is a hard-coded string
              key
              ;; we assume it is a variable reference
              (parse-variable-phrase (princ-to-string key)))
         ,@args)
        ,@(process-tokens rest)))))

(def-token-compiler :translation (key &rest args)
  (lambda (stream)
    (let ((key-val
            (if (stringp key)
                key
                (resolve-variable-phrase key))))
      (princ (translate key-val (resolve-plist args)) stream))))

(def-filter :trans (it &rest args)
  (translate it args))
