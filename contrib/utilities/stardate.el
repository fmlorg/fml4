;;; stardate.el --- GNU Emacs interface to the MH mail system
;;;  $Id$
;;;  Copyright (C) 1993-1997 Ken'ichi Fukamachi
;;;           All rights reserved. 
;;;                1993-1996 fukachan@phys.titech.ac.jp
;;;                1996-1997 fukachan@sapporo.iij.ad.jp
;;;  
;;;  FML is free software; you can redistribute it and/or modify
;;;  it under the terms of GNU General Public License.
;;;  See the file COPYING for more details.

(defconst startrek-version "1.0"
  "Append X-Stardate: STARTREK STARDATE in MH draft buffer")

;; stardate.el is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; stardate.el is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with stardate.el; see the file COPYING.  If not, write to
;; the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.

(provide 'startrek)
;;;(setq debug-on-error t)

(defvar startrek-stardate-process "~/work/spool/EXP/libStardate.pl")

(defun startrek-get-stardate ()
  (interactive)
  (let* ((bufname " *tmp*")
	 (buf (get-buffer-create bufname)))
    (save-excursion
      (set-buffer buf)
      (erase-buffer)
      (call-process startrek-stardate-process nil buf)
      (buffer-substring (point-min) (1- (point-max))))))

;;;(setq mh-letter-mode-hook ; emacs 18
(add-hook 'mh-letter-mode-hook
 	  '(lambda ()
 	     (mh-goto-header-end 0)
	     (mh-insert-fields "X-Stardate:" (startrek-get-stardate))
 	     (forward-line 1)))
