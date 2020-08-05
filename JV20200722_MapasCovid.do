/*******************************************************************************
JV20200721_MapasCovid.do
Autor: Javier Valverde
Versión: 2.2
Insumos:
	-JV20200743_IndiceAmenazaCovid.xlsx

Este do descarga la información más actualizada de los contagios y fallecimientos por COVID-19, agrega la información por estado,
y calcula los índices de Vulnerabilidad y Riesgo a la Vida, y exporta los mapas de dichos índices.

Actualización:
-Establece los intervalos de las etiquetas de leyenda automáticamente
-Corrección en las fuentes de Vp, Vc y Rv
-Establece fecha de actualización de los datos automáticamente

*******************************************************************************/

clear all
set more off
cls

*La dirección de la carpeta donde guardo los archivos auxiliares
gl docs = "D:\Javier\Documents\CEEY\COVID-19\Indices Vulnerabilidad"

*La dirección de la carpeta donde guardaré los mapas resultantes
capture mkdir "$docs\Mapas_Stata"
gl output = "$docs\Mapas_Stata"

*La dirección de la carpeta donde se encuentra mi archivo .shp para elaborar los mapas
gl map_root = "C:\Mapa Digital 6\Proyecto basico de informacion\marco geoestadistico nacional 2010"

*Establecer fecha del día de los datos más recientes
local time : display "$S_TIME"
local current_hour = substr("`time'",1,2)
local refresh_hour = 21
scalar diff_hour = `current_hour' - `refresh_hour'

local fecha: display %tdYND date(c(current_date), "DMY")
local yesterday: display %tdYND date(c(current_date), "DMY") - 1

if diff_hour <= 0{
	local fecha = `yesterday'
}

global current_date: di %tdDD/NN/YY date(c(current_date), "DMY")

capture mkdir "$docs\Datos_Covid"
cd "$docs\Datos_Covid"

*Descargamos la base del día corriente
copy "http://187.191.75.115/gobmx/salud/datos_abiertos/datos_abiertos_covid19.zip" datos_abiertos_covid19.zip, replace
*La descomprimimos
unzipfile datos_abiertos_covid19.zip, replace

*Importamos la base con el nombre generado por la combinación de la fecha y el nombre
local file_format = "COVID19MEXICO.csv"
local file_name = "`fecha'"+ "`file_format'"
import delim `file_name'
tempfile datos_abiertos_covid
save `datos_abiertos_covid'

*Calculamos el número de contagiados con resultado positivo por entidad
collapse (count) confirmados = origen if resultado == 1, by (entidad_um)

*Escribimos los resultados en el Excel actualizable
mkmat confirmados
cd "$docs"
putexcel set "JV20200751_IndiceAmenazaCovid.xlsx", sheet("Confirmados_ACTUALIZABLE") modify
putexcel B2 = matrix(confirmados)

*Importamos de nuevo la base 
clear
cd "$docs\Datos_Covid"
use `datos_abiertos_covid'

*Calculamos el número de defunciones con resultado positivo por entidad
collapse (count) defunciones = origen if (resultado == 1 & fecha_def != "9999-99-99"), by (entidad_um)

*Escribimos los resultados en el Excel Actualizable
mkmat defunciones
cd "$docs"
putexcel set "JV20200751_IndiceAmenazaCovid.xlsx", sheet("Confirmados_ACTUALIZABLE") modify
putexcel C2 = matrix(defunciones)


*IMPORTANTE: Debido a que al importar el archivo de Excel este no actualiza sus formulas automáticamente
*(por alguna razón que aún no logro solucionar), es necesario abrir el archivo de Excel manualmente antes de continuar
*con el resto del código, a fin de que los índices se actualicen. Asegurarse de que las fórmulas se actualizaron en Excel
*Presionando F9 y guardando

*Tl,dr: Abrir el archivo de Excel "JV20200743_IndiceAmenazaCovid.xlsx",
*presionar F9 y guardar antes de continuar con el resto del do.



*Importar el archivo de Excel con los índices calculados y su ranking
cd "$docs"
import excel "$docs\JV20200751_IndiceAmenazaCovid.xlsx", sheet("RiesgoCovid_Vulnerabilidad_A") cellrange(A1:U33) firstrow clear
save "$docs\Valores_Mapas_Covid.dta", replace

*Importar el archivo .shp. Importante cambiar el nombre si tu archivo se llama distinto. Yo utilizo el .shp del Marco Geoestadístico Nacional 2010 de Mapa Digital de INEGI
shp2dta using "$map_root\estatal.shp", database(estatalDb) coordinates(estatalCo) genid(id) replace

use estatalDb
capture keep CVEGEO CVEGEO NOM_ENT OID id	//Nombres de variables que se van a conservar. comentar y cambiar por otras variables en caso de utilizar un .shp distinto

merge 1:1 CVEGEO using "Valores_Mapas_Covid.dta"

rename( Pobmásvulnerable60 Camaspor100milhab UCIpormillhab PersonalMédicopormilhab GastoFederalenFunciónSaludp Pobenhacinamiento Pobsinaccesoaagua Pobsindrenaje AmenazaporCovidAv IndicedeAmenazaporMortalidad VulnerabilidadPersonalVp VulnerabilidaddelSistemadeSa VulnerabilidadConjuntaVc IndicedeRiesgoalaVidaR) (pob_vulnerable camas uci medicos gasto_federal_salud pob_hacinamiento pob_sin_agua pob_sin_drenaje confirmados_covid mortalidad_covid Vp Vs Vc Rv)

*============Mapas de Índices de vulnerabilidades==============

*--------Av------------
qui sum confirmados_covid
scalar Av_baja_min = round(r(min), 0.001)
scalar Av_baja_max = round(r(mean) - r(sd), 0.001)
scalar Av_media_min = `=Av_baja_max+0.001'
scalar Av_media_max = round(r(mean) + r(sd), 0.001)
scalar Av_alta_min = `=Av_media_max+0.001'
scalar Av_alta_max = round(r(max), 0.001)

global Av_baja_label: di "Baja (" `=Av_baja_min' " - " `=Av_baja_max' ")"
global Av_media_label: di "Media (" `=Av_media_min' " - " `=Av_media_max' ")"
global Av_alta_label: di "Alta (" `=Av_alta_min' " - " `=Av_alta_max' ")"

spmap SemaforoAv using estatalCo, ///
id(id) clmethod(unique) ///
fcolor("255 128 0" "204 102 0" "102 51 0") ///
ndlab("Sin datos") ndfcolor(gs13) ndocolor(none ..) ///
ocolor(white ..) osize(vthin ..) ///
legend(label(2 "$Av_baja_label") label(3 "$Av_media_label") label(4 "$Av_alta_label") pos() row(6) ring(0) size(*1.5) symx(*1.3) symy(*1) style(2) forcesize) legstyle(2) legorder(hilo) ///
title("Índice de Amenaza a la vida por COVID-19 (Av)", size(*1) margin(medsmall) bexpand) ///
caption("Elaboración propia con datos de la Secretaría de Salud (2020)", size(small) position(7) margin(b+2 t+1 l=0) bexpand) ///
note("Nota: Se considera amenaza Baja si el Índice de amenaza es menor a la media menos una desviación estándar;" "Alta, si es mayor a la media más una desviación estándar, y Media si se encuentra en medio." "Datos actualizados al $current_date.", size(vsmall) margin(b+3 t+1.3 l=0) bexpand)

graph export "$output\JV20200741_Av.png", width(1020) replace

*--------Vc-----------
qui sum Vc
scalar Vc_baja_min = round(r(min), 0.001)
scalar Vc_baja_max = round(r(mean) - r(sd), 0.001)
scalar Vc_media_min = `=Vc_baja_max+0.001'
scalar Vc_media_max = round(r(mean) + r(sd), 0.001)
scalar Vc_alta_min = `=Vc_media_max+0.001'
scalar Vc_alta_max = round(r(max), 0.001)

global Vc_baja_label: di "Baja (" `=Vc_baja_min' " - " `=Vc_baja_max' ")"
global Vc_media_label: di "Media (" `=Vc_media_min' " - " `=Vc_media_max' ")"
global Vc_alta_label: di "Alta (" `=Vc_alta_min' " - " `=Vc_alta_max' ")"

spmap SemaforoVc using estatalCo, ///
id(id) clmethod(unique) ///
fcolor("255 128 0" "204 102 0" "102 51 0") ///
ndlab("Sin datos") ndfcolor(gs13) ndocolor(none ..) ///
ocolor(white ..) osize(vthin ..) ///
legend(label(2 "$Vc_baja_label") label(3 "$Vc_media_label") label(4 "$Vc_alta_label") pos() row(6) ring(0) size(*1.5) symx(*1.3) symy(*1) style(2) forcesize) legstyle(2) legorder(hilo) ///
title("Índice de Vulnerabilidad Conjunta (Vc)", size(*1) margin(medsmall) bexpand) ///
caption("Elaboración propia con datos de INEGI (2016), CONEVAL (2018), CONAPO (2016)" "Secretaría de Salud (2017) y Transparencia Presupuestaria (2020)", size(small) position(7) margin(b+2 t+1 l=0) bexpand) ///
note("Nota: Se considera vulnerabilidad Baja si el Índice de vulnerabilidad es menor a la media menos una desviación estándar;" "Alta, si es mayor a la media más una desviación estándar, y Media si se encuentra en medio." , size(vsmall) margin(b+3 t+1.3 l=0) bexpand)

graph export "$output\JV20200741_Vc.png", width(1020) replace

*-------Vs----------
qui sum Vs
scalar Vs_baja_min = round(r(min), 0.001)
scalar Vs_baja_max = round(r(mean) - r(sd), 0.001)
scalar Vs_media_min = `=Vs_baja_max+0.001'
scalar Vs_media_max = round(r(mean) + r(sd), 0.001)
scalar Vs_alta_min = `=Vs_media_max+0.001'
scalar Vs_alta_max = round(r(max), 0.001)

global Vs_baja_label: di "Baja (" `=Vs_baja_min' " - " `=Vs_baja_max' ")"
global Vs_media_label: di "Media (" `=Vs_media_min' " - " `=Vs_media_max' ")"
global Vs_alta_label: di "Alta (" `=Vs_alta_min' " - " `=Vs_alta_max' ")"

spmap SemaforoVs using estatalCo, ///
id(id) clmethod(unique) ///
fcolor("255 128 0" "204 102 0" "102 51 0") ///
ndlab("Sin datos") ndfcolor(gs13) ndocolor(none ..) ///
ocolor(white ..) osize(vthin ..) ///
legend(label(2 "$Vs_baja_label") label(3 "$Vs_media_label") label(4 "$Vs_alta_label") pos() row(6) ring(0) size(*1.5) symx(*1.3) symy(*1) style(2) forcesize) legstyle(2) legorder(hilo) ///
title("Índice de Vulnerabilidad del Sistema de Salud (Vs)", size(*1) margin(medsmall) bexpand) ///
caption("Elaboración propia con datos de la Secretaría de Salud (2017) y Transparencia Presupuestaria (2020)", size(small) position(7) margin(b+2 t+1 l=0) bexpand) ///
note("Nota: Se considera vulnerabilidad Baja si el Índice de vulnerabilidad es menor a la media menos una desviación estándar;" "Alta, si es mayor a la media más una desviación estándar, y Media si se encuentra en medio." , size(vsmall) margin(b+3 t+1.3 l=0) bexpand)

graph export "$output\JV20200741_Vs.png", width(1020) replace

*-------Vp----------
qui sum Vp
scalar Vp_baja_min = round(r(min), 0.001)
scalar Vp_baja_max = round(r(mean) - r(sd), 0.001)
scalar Vp_media_min = `=Vp_baja_max+0.001'
scalar Vp_media_max = round(r(mean) + r(sd), 0.001)
scalar Vp_alta_min = `=Vp_media_max+0.001'
scalar Vp_alta_max = round(r(max), 0.001)

global Vp_baja_label: di "Baja (" `=Vp_baja_min' " - " `=Vp_baja_max' ")"
global Vp_media_label: di "Media (" `=Vp_media_min' " - " `=Vp_media_max' ")"
global Vp_alta_label: di "Alta (" `=Vp_alta_min' " - " `=Vp_alta_max' ")"

spmap SemaforoVp using estatalCo, ///
id(id) clmethod(unique) ///
fcolor("255 128 0" "204 102 0" "102 51 0") ///
ndlab("Sin datos") ndfcolor(gs13) ndocolor(none ..) ///
ocolor(white ..) osize(vthin ..) ///
legend(label(2 "$Vp_baja_label") label(3 "$Vp_media_label") label(4 "$Vp_alta_label") pos() row(6) ring(0) size(*1.5) symx(*1.3) symy(*1) style(2) forcesize) legstyle(2) legorder(hilo) ///
title("Índice de Vulnerabilidad Personal (Vp)", size(*1) margin(medsmall) bexpand) ///
caption("Elaboración propia con datos de INEGI (2016), CONEVAL (2018) y CONAPO(2016)", size(small) position(7) margin(b+2 t+1 l=0) bexpand) ///
note("Nota: Se considera vulnerabilidad Baja si el Índice de vulnerabilidad es menor a la media menos una desviación estándar;" "Alta, si es mayor a la media más una desviación estándar, y Media si se encuentra en medio.", size(vsmall) margin(b+3 t+1.3 l=0) bexpand)

graph export "$output\JV20200741_Vp.png", width(1020) replace

*-------Rv-----------
qui sum Rv
scalar Rv_baja_min = round(r(min), 0.001)
scalar Rv_baja_max = round(r(mean) - r(sd), 0.001)
scalar Rv_media_min = `=Rv_baja_max+0.001'
scalar Rv_media_max = round(r(mean) + r(sd), 0.001)
scalar Rv_alta_min = `=Rv_media_max+0.001'
scalar Rv_alta_max = round(r(max), 0.001)

global Rv_baja_label: di "Bajo (" `=Rv_baja_min' " - " `=Rv_baja_max' ")"
global Rv_media_label: di "Medio (" `=Rv_media_min' " - " `=Rv_media_max' ")"
global Rv_alta_label: di "Alto (" `=Rv_alta_min' " - " `=Rv_alta_max' ")"

spmap SemaforoRv using estatalCo, ///
id(id) clmethod(unique) ///
fcolor("255 128 0" "204 102 0" "102 51 0") ///
ndlab("Sin datos") ndfcolor(gs13) ndocolor(none ..) ///
ocolor(white ..) osize(vthin ..) ///
legend(label(2 "$Rv_baja_label") label(3 "$Rv_media_label") label(4 "$Rv_alta_label") pos() row(6) ring(0) size(*1.5) symx(*1.3) symy(*1) style(2) forcesize) legstyle(2) legorder(hilo) ///
title("Índice de Riesgo a la Vida por COVID-19 (Rv)", size(*1) margin(medsmall) bexpand) ///
caption("Elaboración propia con datos de CONAPO (2016), CONEVAL (2018), INEGI (2016)" "Secretaría de Salud (2017, 2020) y Transparencia Presupuestaria (2020)", size(small) position(7) margin(b+2 t+1 l=0) bexpand) ///
note("Nota: Se considera Riesgo Bajo si el Índice de Riesgo es menor a la media menos una desviación estándar;" "Alto, si es mayor a la media más una desviación estándar, y Medio si se encuentra en medio." "Datos actualizados al $current_date", size(vsmall) margin(b+3 t+1.3 l=0) bexpand)

graph export "$output\JV20200741_Rv.png", width(1020) replace

*Fin*
