#lang racket/gui

(require racket/system)
(require json)

(define frame (new frame% [label "Stroke Prediction App"]
                   [width 400]
                   [height 600]))

(define panel (new vertical-panel% [parent frame] [alignment '(center top)] [spacing 10]))


;; Inputs
(define gender-choice (new choice% [label "Cinsiyet"] [parent panel] [choices '("Erkek" "Kadın" "Diğer")]))
(define age-field (new text-field% [label "Yaş (0.08 - 82)"] [parent panel]))
(define hypertension-check (new check-box% [label "Hipertansiyon"] [parent panel]))
(define heart-disease-check (new check-box% [label "Kalp Hastalığı"] [parent panel]))
(define married-choice (new choice% [label "Evlilik Durumu"] [parent panel] [choices '("Evet" "Hayır")]))
(define work-choice (new choice% [label "Çalışma Şekli"] [parent panel] [choices '("Özel Sektör" "Serbest Meslek" "Devlet Memuru" "Çocuk" "Hiç Çalışmadı")]))
(define res-choice (new choice% [label "Yaşadığı Yer"] [parent panel] [choices '("Şehir" "Kırsal")]))
(define glucose-field (new text-field% [label "Ortalama Şeker (55.12 - 271.74)"] [parent panel]))
(define bmi-field (new text-field% [label "BMI (Vücut Kitle İndeksi) (10.3 - 97.6)"] [parent panel]))
(define smoking-choice (new choice% [label "Sigara Durumu"] [parent panel] [choices '("Eskiden içiyordu" "Hiç içmedi" "İçiyor" "Bilinmiyor")]))

(define result-msg (new message% [label "Sonuç burada görünecek"] [parent panel] [auto-resize #t]))

(define (get-string-selection choice)
  (send choice get-string-selection))

;; Translation Helpers (Turkish to English for backend)
(define (trans-gender g)
  (cond [(equal? g "Erkek") "Male"]
        [(equal? g "Kadın") "Female"]
        [else "Other"]))

(define (trans-married m)
  (if (equal? m "Evet") "Yes" "No"))

(define (trans-work w)
  (cond [(equal? w "Özel Sektör") "Private"]
        [(equal? w "Serbest Meslek") "Self-employed"]
        [(equal? w "Devlet Memuru") "Govt_job"]
        [(equal? w "Çocuk") "children"]
        [else "Never_worked"]))

(define (trans-res r)
  (if (equal? r "Şehir") "Urban" "Rural"))

(define (trans-smoke s)
  (cond [(equal? s "Eskiden içiyordu") "formerly smoked"]
        [(equal? s "Hiç içmedi") "never smoked"]
        [(equal? s "İçiyor") "smokes"]
        [else "Unknown"]))

(define (predict-stroke button event)
  ;; Get values and translate to English
  (define gender (trans-gender (get-string-selection gender-choice)))
  (define age (send age-field get-value))
  (define hypertension (if (send hypertension-check get-value) "1" "0"))
  (define heart-disease (if (send heart-disease-check get-value) "1" "0"))
  (define married (trans-married (get-string-selection married-choice)))
  (define work (trans-work (get-string-selection work-choice)))
  (define res (trans-res (get-string-selection res-choice)))
  (define glucose (send glucose-field get-value))
  (define bmi (send bmi-field get-value))
  (define smoking (trans-smoke (get-string-selection smoking-choice)))
  
  ;; Get absolute path to predict.py
  (define script-path (path->string (build-path (current-directory) "predict.py")))
  
  ;; Absolute path to wrapper.bat
  (define wrapper-path (path->string (build-path (current-directory) "wrapper.bat")))
  
  ;; Debug: Print intended execution
  (printf "Executing Wrapper: ~a ...\n" wrapper-path)

  (define-values (process stdout stdin stderr) 
    (subprocess #f #f #f 
                wrapper-path 
                "--gender" gender 
                "--age" age 
                "--hypertension" hypertension 
                "--heart_disease" heart-disease 
                "--ever_married" married 
                "--work_type" work 
                "--residence_type" res 
                "--avg_glucose_level" glucose 
                "--bmi" bmi 
                "--smoking_status" smoking))
  
  (subprocess-wait process)
  (define exit-code (subprocess-status process))
  
  (define out-str (port->string stdout))
  (define err-str (port->string stderr))
  
  (close-input-port stdout)
  (close-input-port stderr)
  (close-output-port stdin)
  
  (printf "Exit Code: ~a\n" exit-code)
  (printf "Stdout: ~a\n" out-str)
  (printf "Stderr: ~a\n" err-str)

  (define now (current-seconds))
  (define timestamp (seconds->date now))
  (define time-str (format "~a:~a:~a" 
                           (date-hour timestamp) 
                           (date-minute timestamp) 
                           (date-second timestamp)))

  (if (non-empty-string? err-str)
      (send result-msg set-label (format "[~a] Hata: ~a" time-str err-str))
      (if (non-empty-string? out-str)
          (let ([prob-match (regexp-match #rx"Probability: ([0-9.]+)" out-str)])
            (if prob-match
                (let* ([prob-str (list-ref prob-match 1)]
                       [prob (string->number prob-str)]
                       [prob-percent (* prob 100)])
                  (cond
                    [(>= prob 0.22) (send result-msg set-label (format "[~a]\nRİSK SEVİYESİ: YÜKSEK 🔴\nOlasılık: %~a" time-str (~r prob-percent #:precision 2)))]
                    [(>= prob 0.10) (send result-msg set-label (format "[~a]\nRİSK SEVİYESİ: ORTA 🟠\nOlasılık: %~a" time-str (~r prob-percent #:precision 2)))]
                    [else (send result-msg set-label (format "[~a]\nRİSK SEVİYESİ: DÜŞÜK 🟢\nOlasılık: %~a" time-str (~r prob-percent #:precision 2)))]))
                (send result-msg set-label (format "[~a]\n~a" time-str out-str))))
          (send result-msg set-label (format "[~a] Çıktı yok. Çıkış Kodu: ~a" time-str exit-code)))))

(define predict-btn (new button% [parent panel]
                         [label "Felç Riskini Hesapla"]
                         [callback predict-stroke]))

(send frame show #t)
