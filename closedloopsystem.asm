list p=16f716			
#include "p16f716.inc"	

org	0x0000			; Reset vector
nop
goto init			; Переход к инициализации

; --- Объявление переменных ---
conv_st	EQU 0x70		; Заданное значение (с потенциометра)
conv_fb	EQU 0x71		; Обратная связь (текущее состояние)
error	EQU 0x72		; Ошибка управления
delay_var	EQU 0x73	; Переменная для задержки

; --- Инициализация ---
init
	banksel TRISA
	bsf TRISA,0			; RA0 - вход (обратная связь)
	bsf TRISA,1			; RA1 - вход (заданное значение)

	banksel TRISC
	bcf TRISC,1			; RC1 - DIR (направление)
	bcf TRISC,2			; RC2 - PWM (ШИМ)

	banksel ADCON1
	movlw 0x80			; ADFM = 1 (правое выравнивание), RA0/RA1 = аналоговые входы
	movwf ADCON1

	banksel ADCON0
	movlw 0x41			; Включение АЦП, выбор AN0 (RA0), частота Fosc/8
	movwf ADCON0

	banksel PR2
	movlw 0xFF			; Установка максимального периода PWM
	movwf PR2

	banksel CCP1CON
	movlw 0x0C			; Режим PWM
	movwf CCP1CON

	banksel T2CON
	movlw 0x04			; Предделитель таймера 2 = 16
	movwf T2CON
	bsf T2CON,TMR2ON		; Запуск таймера 2

	goto main_loop			; Переход к основному циклу

; --- Основной цикл ---
main_loop
	call read_pot			; Считать значение с потенциометра (заданное)
	call read_feedback		; Считать значение обратной связи
	call calc_error			; Вычислить ошибку
	call pwm_control		; Обновить ШИМ и направление
	goto main_loop			; Повторять

; --- Чтение заданного значения ---
read_pot
	banksel ADCON0
	movlw 0x41			; Выбор AN1 (RA1)
	movwf ADCON0
	bsf ADCON0,GO_DONE		; Запуск преобразования
wait_adc_pot
	btfsc ADCON0,GO_DONE		; Ожидание завершения
	goto wait_adc_pot

	banksel ADRESL
	movf ADRESL,W			; Сохранить младший байт
	movwf conv_st
	return

; --- Чтение обратной связи ---
read_feedback
	banksel ADCON0
	movlw 0x40			; Выбор AN0 (RA0)
	movwf ADCON0
	bsf ADCON0,GO_DONE		; Запуск преобразования
wait_adc_fb
	btfsc ADCON0,GO_DONE		; Ожидание завершения
	goto wait_adc_fb

	banksel ADRESL
	movf ADRESL,W			; Сохранить младший байт
	movwf conv_fb
	return

; --- Вычисление ошибки ---
calc_error
	banksel conv_st
	movf conv_st,W			; Заданное значение
	subwf conv_fb,W			; Вычитание обратной связи
	movwf error			; Сохранение ошибки
	return

; --- Управление ШИМ и направлением ---
pwm_control
	banksel error
	btfsc error,7			; Проверка знака ошибки
	call change_dir_1		; Если отрицательная ошибка, направление 1
	btfss error,7
	call change_dir_0		; Если положительная ошибка, направление 0

	movf error,W			; Передача ошибки в ШИМ
	banksel CCPR1L
	movwf CCPR1L			; Обновление ширины ШИМ
	return

; --- Управление направлением ---
change_dir_0
	banksel PORTC
	bcf PORTC,1			; Установить направление 0
	return

change_dir_1
	banksel PORTC
	bsf PORTC,1			; Установить направление 1
	return

; --- Задержка ---
delay
	movlw 0x50
	movwf delay_var
delay_loop
	decfsz delay_var,F
	goto delay_loop
	return

end
