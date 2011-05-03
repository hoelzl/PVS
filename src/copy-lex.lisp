;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; -*- Mode: Lisp -*- ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; copy-lex.lisp -- 
;; Author          : Sam Owre
;; Created On      : Sun Feb 27 01:34:00 1994
;; Last Modified By: Sam Owre
;; Last Modified On: Thu Nov  5 15:10:01 1998
;; Update Count    : 10
;; Status          : Stable
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; --------------------------------------------------------------------
;; PVS
;; Copyright (C) 2006, SRI International.  All Rights Reserved.

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
;; --------------------------------------------------------------------

(in-package :pvs)

(defvar *copy-lex-exact* nil)
(defvar *copy-lex-view-hash* nil)

;;; Primarily copies the place information from the newobj to the oldobj.
;;; This is used when, for example, a PVS file is changed by adding
;;; comments.  If the optional (eq) view-hash is provided, the place is
;;; stored in the view-hash, rather than modifying oldobj.
(defun copy-lex (oldobj newobj &optional exact? view-hash)
  (let ((*copy-lex-exact* exact?)
	(*copy-lex-view-hash* view-hash))
    (copy-lex* oldobj newobj)))

(defmethod copy-lex-upto (diff (oth module) (nth module))
  (cond ((memq (car diff) (formals oth))
	 (assert (or (null (cdr diff)) (memq (cdr diff) (formals nth))))
	 (copy-lex-decls (ldiff (memq (car diff) (formals oth)) (formals oth))
			 (memq (cdr diff) (formals nth))))
	((memq (car diff) (assuming oth))
	 (assert (or (null (cdr diff)) (memq (cdr diff) (assuming nth))))
	 (copy-lex-decls (formals oth) (formals nth))
	 (copy-lex-decls (ldiff (memq (car diff) (assuming oth)) (assuming oth))
			 (memq (cdr diff) (assuming nth))))
	(t
	 (assert (memq (car diff) (theory oth)))
	 (assert (or (null (cdr diff)) (memq (cdr diff) (theory nth))))
	 (copy-lex-decls (formals oth) (formals nth))
	 (copy-lex-decls (assuming oth) (assuming nth))
	 (copy-lex-decls (ldiff (memq (car diff) (theory oth)) (theory oth))
			 (memq (cdr diff) (theory nth))))))

(defmethod copy-lex-upto (diff (oth recursive-type) (nth recursive-type))
  (break))

(defmethod copy-lex* :around ((old syntax) (new syntax))
  (call-next-method)
  ;;(setf (newline-comment old) (newline-comment new))
  ;;(setf (abstract-syntax old) (abstract-syntax new))
  (if *copy-lex-view-hash*
      (setf (gethash old *copy-lex-view-hash*) (place new))
      (setf (place old) (place new))))

(defmethod copy-lex* :around ((old datatype-or-module) (new datatype-or-module))
  (call-next-method)
  (copy-lex-decls (formals old) (formals new))
  (copy-lex-decls (assuming old) (assuming new)))

(defmethod copy-lex* ((old module) (new module))
  (copy-lex* (exporting old) (exporting new))
  (copy-lex-decls (theory old) (theory new)))

(defmethod copy-lex* ((old datatype) (new datatype))
  (copy-lex* (importings old) (importings new))
  (copy-lex* (constructors old) (constructors new)))

;;; inline-datatype not needed

;;; enumtype not needed

(defmethod copy-lex* ((old simple-constructor) (new simple-constructor))
  ;;(copy-lex* (recognizer old) (recognizer new))
  (copy-lex* (arguments old) (arguments new)))

(defmethod copy-lex* ((old exporting) (new exporting))
  (copy-lex* (names old) (names new))
  (copy-lex* (but-names old) (but-names new))
  (copy-lex* (modules old) (modules new)))

(defmethod copy-lex* ((old expname) (new expname))
  )

(defmethod copy-lex* ((old importing) (new importing))
  (copy-lex* (theory-name old) (theory-name new))
  (unless *copy-lex-view-hash*
    (setf (semi old) (semi new))
    (setf (chain? old) (chain? new))))


(defun copy-lex-decls (old-list new-list)
  (when old-list
    (cond ((and (not *copy-lex-exact*)
		(or (typep (car old-list) 'field-decl)
		    (generated-by (car old-list))))
	   (copy-lex-decls (cdr old-list) new-list))
	  (t (copy-lex* (car old-list) (car new-list))
	     (copy-lex-decls (cdr old-list) (cdr new-list))))))

(defmethod copy-lex* :around ((old declaration) (new declaration))
  (call-next-method)
  (assert (or *copy-lex-view-hash*
	      (equalp (place old) (place new))))
  (copy-lex* (formals old) (formals new))
  (unless *copy-lex-view-hash*
    (setf (chain? old) (chain? new))
    (setf (semi old) (semi new))))

(defmethod copy-lex* :around ((old typed-declaration) (new typed-declaration))
  (call-next-method)
  (copy-lex* (declared-type old) (declared-type new)))

;; (defmethod copy-lex* ((old declaration) (new declaration))
;;   (call-next-method))

(defmethod copy-lex* ((old typed-declaration) (new typed-declaration))
  )

(defmethod copy-lex* ((old formal-type-decl) (new formal-type-decl))
  (call-next-method)
  (when (type old)
    (if *copy-lex-view-hash*
	(setf (gethash (type old) *copy-lex-view-hash*) (place new))
	(setf (place (type old)) (place new))))
  (when (type-value old)
    (if *copy-lex-view-hash*
	(setf (gethash (type-value old) *copy-lex-view-hash*) (place new))
	(setf (place (type-value old)) (place new)))))

(defmethod copy-lex* ((old mod-decl) (new mod-decl))
  (copy-lex* (modname old) (modname new)))

(defmethod copy-lex* ((old theory-abbreviation-decl)
		      (new theory-abbreviation-decl))
  (copy-lex* (theory-name old) (theory-name new)))

(defmethod copy-lex* ((old type-def-decl) (new type-def-decl))
  (copy-lex* (type-expr old) (type-expr new))
  (copy-lex* (contains old) (contains new)))

(defmethod copy-lex* ((old const-decl) (new const-decl))
  (copy-lex* (definition old) (definition new)))

(defmethod copy-lex* ((old def-decl) (new def-decl))
  (copy-lex* (declared-measure old) (declared-measure new)))

(defmethod copy-lex* ((old formula-decl) (new formula-decl))
  (unless *copy-lex-view-hash*
    (setf (spelling old) (spelling new)))
  (copy-lex* (definition old) (definition new)))

(defmethod copy-lex* ((old subtype-judgement) (new subtype-judgement))
  (call-next-method)
  (copy-lex* (declared-subtype old) (declared-subtype new)))

(defmethod copy-lex* ((old number-judgement) (new number-judgement))
  (call-next-method)
  (copy-lex* (number-expr old) (number-expr new)))

(defmethod copy-lex* ((old name-judgement) (new name-judgement))
  (call-next-method)
  (copy-lex* (name old) (name new)))

(defmethod copy-lex* ((old application-judgement) (new application-judgement))
  (call-next-method)
  (copy-lex* (name old) (name new))
  (copy-lex* (formals old) (formals new)))

(defmethod copy-lex* ((old conversion-decl) (new conversion-decl))
  (unless (eq (class-of old) (class-of new))
    (change-class old (class-of new)))
  (copy-lex* (expr old) (expr new)))

(defmethod copy-lex* ((old auto-rewrite-decl) (new auto-rewrite-decl))
  (unless (eq (class-of old) (class-of new))
    (change-class old (class-of new)))
  (copy-lex* (rewrite-names old) (rewrite-names new)))


;;; Type expressions

(defmethod copy-lex* :around ((old type-expr) (new type-expr))
  (when (print-type old)
    (copy-lex* (print-type old) new))
  (call-next-method)
  (unless *copy-lex-view-hash*
    (setf (parens old) (parens new))))

(defmethod copy-lex* ((old type-expr) (new type-expr))
  )

(defmethod copy-lex* ((old type-name) (new type-name))
  (when (and (null (actuals old))
	     (actuals new))
    (unless *copy-lex-view-hash*
      (setf (actuals old) (actuals (module-instance (resolution old))))))
  (copy-lex* (actuals old) (actuals new)))

(defmethod copy-lex* ((old type-application) (new type-application))
  (copy-lex* (type old) (type new))
  (copy-lex* (parameters old) (parameters new)))

(defmethod copy-lex* ((old subtype) (new subtype))
  (when (supertype new)
    (copy-lex* (supertype old) (supertype new)))
  (copy-lex* (predicate old) (predicate new)))

(defmethod copy-lex* ((old setsubtype) (new setsubtype))
  (cond ((formals old)
	 (copy-lex* (formals old) (formals new))
	 (copy-lex* (formula old) (formula new))
	 (copy-lex* (supertype old) (supertype new)))
	(t (copy-lex* (predicate old) (predicate new)))))

(defmethod copy-lex* ((old nsetsubtype) (new nsetsubtype))
  (cond ((formals old)
	 (copy-lex* (formals old) (formals new))
	 (copy-lex* (formula old) (formula new)))
	(t (copy-lex* (predicate old) (predicate new)))))

(defmethod copy-lex* ((old expr-as-type) (new expr-as-type))
  (copy-lex* (expr old) (expr new)))

(defmethod copy-lex* ((old funtype) (new funtype))
  (unless (eq (class-of old) (class-of new))
    (change-class old (class-of new)))
  (copy-lex* (domain old) (domain new))
  (copy-lex* (range old) (range new)))

(defmethod copy-lex* ((old tupletype) (new tupletype))
  (copy-lex* (types old) (types new)))

(defmethod copy-lex* ((old cotupletype) (new cotupletype))
  (copy-lex* (types old) (types new)))

(defmethod copy-lex* ((old recordtype) (new recordtype))
  (copy-lex* (fields old) (fields new)))


;;; Expressions

(defmethod copy-lex* :around ((old expr) (new expr))
  (call-next-method)
  (unless *copy-lex-view-hash*
    (setf (parens old) (parens new))))

(defmethod copy-lex* ((old number-expr) (new number-expr))
  )

(defmethod copy-lex* ((old tuple-expr) (new tuple-expr))
  (copy-lex* (exprs old) (exprs new)))

(defmethod copy-lex* ((old record-expr) (new record-expr))
  (copy-lex* (assignments old) (assignments new)))

(defmethod copy-lex* ((old cases-expr) (new cases-expr))
  (copy-lex* (expression old) (expression new))
  (copy-lex* (selections old) (selections new))
  (copy-lex* (else-part old) (else-part new)))

(defmethod copy-lex* ((old selection) (new selection))
  (copy-lex* (constructor old) (constructor new))
  (copy-lex* (args old) (args new))
  (copy-lex* (expression old) (expression new)))

(defmethod copy-lex* ((old projection-expr) (new projection-expr))
  (copy-lex* (actuals old) (actuals new)))

(defmethod copy-lex* ((old injection-expr) (new injection-expr))
  (copy-lex* (actuals old) (actuals new)))

(defmethod copy-lex* ((old injection?-expr) (new injection?-expr))
  (copy-lex* (actuals old) (actuals new)))

(defmethod copy-lex* ((old extraction-expr) (new extraction-expr))
  (copy-lex* (actuals old) (actuals new)))

(defmethod copy-lex* ((old projection-application) (new projection-application))
  (copy-lex* (actuals old) (actuals new))
  (copy-lex* (argument old) (argument new)))

(defmethod copy-lex* ((old injection-application) (new injection-application))
  (copy-lex* (actuals old) (actuals new))
  (copy-lex* (argument old) (argument new)))

(defmethod copy-lex* ((old injection?-application) (new injection?-application))
  (copy-lex* (actuals old) (actuals new))
  (copy-lex* (argument old) (argument new)))

(defmethod copy-lex* ((old extraction-application) (new extraction-application))
  (copy-lex* (actuals old) (actuals new))
  (copy-lex* (argument old) (argument new)))

(defmethod copy-lex* ((old field-application) (new field-application))
  (copy-lex* (argument old) (argument new)))

(defmethod copy-lex* ((old field-application) (new application))
  (copy-lex* (argument old) (argument new)))

(defmethod copy-lex* ((old application) (new application))
  (copy-lex* (operator old) (operator new))
  (copy-lex* (argument old) (argument new)))

(defmethod copy-lex* ((old when-expr) (new application))
  (copy-lex* (operator old) (operator new))
  (copy-lex* (argument old) (reverse (exprs (argument new)))))

(defmethod copy-lex* ((old implicit-conversion) (new expr))
  (copy-lex* (args1 old) new))

(defmethod copy-lex* ((old argument-conversion) (new expr))
  (copy-lex* (operator old) new))

(defmethod copy-lex* ((old lambda-conversion) (new expr))
  (copy-lex* (expression old) new))

(defmethod copy-lex* ((old table-expr) (new table-expr))
  (copy-lex* (row-expr old) (row-expr new))
  (copy-lex* (col-expr old) (col-expr new))
  (copy-lex* (row-headings old) (row-headings new))
  (copy-lex* (col-headings old) (col-headings new))
  (copy-lex* (table-entries old) (table-entries new)))

(defmethod copy-lex* ((old binding-expr) (new binding-expr))
  (unless (eq (class-of old) (class-of new))
    (change-class old (class-of new)))
  (copy-lex* (bindings old) (bindings new))
  (copy-lex* (expression old) (expression new)))

(defmethod copy-lex* ((old update-expr) (new update-expr))
  (copy-lex* (assignments old) (assignments new))
  (copy-lex* (expression old) (expression new)))

(defmethod copy-lex* ((old assignment) (new assignment))
  (copy-lex* (arguments old) (arguments new))
  (copy-lex* (expression old) (expression new)))

(defmethod copy-lex* :around ((old simple-decl) (new simple-decl))
  (when (next-method-p) (call-next-method))
  (when (declared-type old)
    (if (declared-type new)
	(copy-lex* (declared-type old) (declared-type new))
	(unless *copy-lex-view-hash*
	  (setf (declared-type old) nil)))))

(defmethod copy-lex* ((old field-decl) (new field-decl))
  (unless *copy-lex-view-hash*
    (setf (chain? old) (chain? new))))

(defmethod copy-lex* ((old bind-decl) (new bind-decl))
  (unless *copy-lex-view-hash*
    (setf (chain? old) (chain? new))))

;;(defmethod copy-lex* ((old modname) (new modname))
;;  (copy-lex* (mappings old) (mappings new)))

(defmethod copy-lex* ((old name) (new name))
  (when (and (null (actuals old))
	     (actuals new))
    (unless *copy-lex-view-hash*
      (setf (actuals old)
	    (mapcar #'copy-all
	      (actuals (module-instance (resolution old)))))))
  (when (actuals new)
    (copy-lex* (actuals old) (actuals new))))

(defmethod copy-lex* ((old actual) (new actual))
  (copy-lex (expr old) (expr new))
  (when (and (type-value old) (type-value new))
    (copy-lex (type-value old) (type-value new))))

(defmethod copy-lex* ((old list) (new list))
  (when old
    (copy-lex* (car old) (car new))
    (copy-lex* (cdr old) (cdr new))))

(defmethod copy-lex* (old new)
  (declare (ignore old new))
  nil)
