rm(list = ls())

library(ggplot2)
library(readxl)
library(ggrepel)
library(dplyr)

library(sf)
library(tmap)
library(tmaptools)

library(extrafont)
loadfonts(device = "win")

options(digits = 2)

mex <- st_read("C:/Mapa Digital 6/Proyecto basico de informacion/marco geoestadistico nacional 2010/estatal.shp", stringsAsFactors = FALSE)
mex <- mex[,c("CVEGEO", "NOM_ENT", "geometry")]

#===========Mapa de vulnerabilidades - Índices =====================
covid <- read_xlsx("D:/Javier/Documents/CEEY/COVID-19/JV20200532_IndiceAmenazaCovid.xlsx", sheet = "RiesgoCovid_Vulnerabilidad_A", range = "A1:N33")


mex_covid <- inner_join(mex, covid)

mex_covid$`Semaforo Media` <- factor(mex_covid$`Semaforo Media`, levels = unique(mex_covid$`Semaforo Media`))

vi <- ggplot(mex_covid) + theme_void() +
  geom_sf(aes(fill = `Semaforo Media`), size = 0.001, color = "white") +
  scale_fill_manual(labels = c(expression('V'[i]*'<='*'0.10'), expression('0.10'*'<'*'V'[i]*'<'*'0.20'), expression('V'[i]*'>='*'0.20')),
                    values = c("#00B000", "#FFFF19", "#B2182B")) +
  labs(caption = "Fuente: Elaboración propia con datos de Secretaría de Salud (2017, 2020) \nNota: Vi construido a partir de la media geométrica de los índices de vulnerabilidad de 9 factores") +
  ggtitle("Riesgo a la vida por Covid-19 de la población vulnerable") +
  theme(plot.title = element_text(hjust = 0.5),
        legend.position = "left",
        legend.title = element_blank(),
        text = element_text(family = "Arial"))

ggsave("D:/Javier/Documents/CEEY/COVID-19/Mapas/Mapas_R/riesgo_vida11_2022.png", plot = vi, width = 16, height = 9, units = "cm")    

#=====================Mapa de confirmados=============================
confirmados <- read_xlsx("D:/Javier/Documents/CEEY/COVID-19/Confirmados_ACTUALIZABLE.xlsx", range = "A1:F33")
names(confirmados) <- c("CVEGEO", "confirmados", "fallecidos", "pop", "confirmados_p", "i_mortalidad")
mex_conf <- inner_join(mex, confirmados)

estrato_covid <- 1
i <- 1
Semaforo_Covid <- rep(0, nrow(mex_covid))

for(n in order(mex_conf$confirmados_p)){
  Semaforo_Covid[n] <- estrato_covid
  i <- i + 1
  estrato_covid <- case_when(
    i <= 5 ~ 1,
    i > 5 & i <= 10 ~ 2,
    i > 10 & i <= 15 ~ 3,
    i > 15 & i <= 20 ~ 4,
    i > 20 & i <= 25 ~ 5,
    i > 25 ~ 6)
}

mex_conf$Semaforo_covid <- Semaforo_Covid
mex_conf$Semaforo_covid <- factor(mex_conf$Semaforo_covid, levels = c("6", "5", "4", "3", "2", "1"))

omc <- order(mex_conf$confirmados_p)

mex_conf$confirmados_p <- round(mex_conf$confirmados_p, 2)

labs_estratos <- c(paste(mex_conf$confirmados_p[[omc[[25]]]] + 0.01, "a", mex_conf$confirmados_p[[omc[[32]]]]),
                   paste(mex_conf$confirmados_p[[omc[[20]]]] + 0.01, "a", mex_conf$confirmados_p[[omc[[25]]]]),
                   paste(mex_conf$confirmados_p[[omc[[15]]]] + 0.01, "a", mex_conf$confirmados_p[[omc[[20]]]]),
                   paste(mex_conf$confirmados_p[[omc[[10]]]] + 0.01, "a", mex_conf$confirmados_p[[omc[[15]]]]),
                   paste(mex_conf$confirmados_p[[omc[[5]]]] + 0.01, "a", mex_conf$confirmados_p[[omc[[10]]]]),
                   paste(mex_conf$confirmados_p[[omc[[1]]]], "a", mex_conf$confirmados_p[[omc[[5]]]]))

cols_estratos <- c("#B2182B", "#EF8A62", "#FFFFB3", "#FFFF19", "#80D880", "#00B000")

contagios <- ggplot(mex_conf) + theme_void() +
  geom_sf(aes(fill = Semaforo_covid), size = 0.001, color = "white") +
  scale_fill_manual(labels = labs_estratos,
                    values = cols_estratos) +
  labs(caption = "Fuente: Elaboración propia con datos de Secretaría de Salud (2020)") +
  ggtitle("Casos confirmados de Covid-19 por millón de habitantes") +
  theme(plot.title = element_text(hjust = 0.5),
        legend.position = "left",
        legend.title = element_blank(),
        text = element_text(family = "Arial"))

ggsave("D:/Javier/Documents/CEEY/COVID-19/Mapas/Mapas_R/confirmados_covid11_2022.png", plot = contagios, width = 16, height = 9, units = "cm")    