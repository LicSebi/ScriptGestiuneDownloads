#!/bin/bash

cd "$(dirname "$0")" || exit 1

CONFIG_FILE="config.cfg"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Fisierul de configurare $CONFIG_FILE nu a fost gasit"
    exit 1
fi

LOG_FILE="$MEDIA_DIR/raport_organizare.log"

mkdir -p "$MEDIA_DIR"

declare -i count_filme=0
declare -i count_seriale=0
declare -i count_muzica=0
declare -i count_restul=0

scrie_log() {
	local mesaj="$1"
	local data_ora=$(date "+%Y-%m-%d %H:%M:%S")
	echo "[$data_ora] $mesaj" >> "$LOG_FILE"
}

pregatire_nume_film() {
	local nume="$1"
	
	#scapam de punct si underscore
	local clean=$(echo "$nume" | tr '._' ' ')

	#pastram doar numele, fara ani, rezolutii, formate etc
	clean=$(echo "$clean" | sed -E 's/([0-9]{4}|1080p|720p|2160p|4k|bluray|brrip|web-dl|hdtv|x264|x265|hevc|yts).*/ /I')
    
	#eliminam spatii si paranteze
	clean=$(echo "$clean" | tr -d '[]()' | xargs)
    
	echo "$clean"
}


proceseaza_film() {
	local file="$1"
	local filename=$(basename "$file")
       
	#xtensia fisierului original
	local extensie=$(echo "$filename" | rev | cut -d'.' -f1 | rev | tr '[:upper:]' '[:lower:]')
    
	local nume_fara_extensie=$(echo "$filename" | rev | cut -d'.' -f2- | rev)
	local nume_curat=$(pregatire_nume_film "$nume_fara_extensie")
    
	#trimitem cerere api
	local raspuns_json=$(curl -s "http://www.omdbapi.com/?apikey=${API_KEY}&t=$(echo "$nume_curat" | jq -sRr @uri)")
    
	# verificam daca filmul a fost gasit
	local status=$(echo "$raspuns_json" | jq -r '.Response')
    
	if [ "$status" = "True" ]; then
		local titlu_oficial=$(echo "$raspuns_json" | jq -r '.Title')
		local an=$(echo "$raspuns_json" | jq -r '.Year')
		local genuri=$(echo "$raspuns_json" | jq -r '.Genre')
        
		#doar primul gen pentru incadrare
		local gen_principal=$(echo "$genuri" | cut -d',' -f1 | xargs)
		local dest_dir="$MEDIA_DIR/Movies/$gen_principal"
		mkdir -p "$dest_dir"
        
		#"Titlu (An).extensie"
		local noul_nume="${titlu_oficial} (${an}).${extensie}"
        
		mv "$file" "$dest_dir/$noul_nume"
		scrie_log "FILM: S-a mutat '$filename' -> '$dest_dir/$noul_nume'"
		((count_filme++))
        
	else
    
		#mutam filmul intr un folder de erori
		local dest_dir_necunoscut="$MEDIA_DIR/Movies/Uncategorized"
		mkdir -p "$dest_dir_necunoscut"
		mv "$file" "$dest_dir_necunoscut/"
		scrie_log "FILM (NEGĂSIT): S-a mutat '$filename' -> '$dest_dir_necunoscut/'"
		((count_filme++))
	fi
}


proceseaza_serial() {
	local file="$1"
	local filename=$(basename "$file")
		
	local extensie=$(echo "$filename" | rev | cut -d'.' -f1 | rev | tr '[:upper:]' '[:lower:]')
		
	local nume_curat=$(echo "$filename" | tr '._' ' ')

	# Variabile pentru a stoca rezultatele extrase
	local nume=""
	local sezon=""
	local episod=""

	# TIPARUL 1: SXXEYY sau sXXeYY 
	if [[ "$nume_curat" =~ ^(.*)[sS]([0-9]+)[eE]([0-9]+)(.*)$ ]]; then
		nume=$(echo "${BASH_REMATCH[1]}" | xargs)
		sezon=$(echo "${BASH_REMATCH[2]}" | xargs)
		episod=$(echo "${BASH_REMATCH[3]}" | xargs)

	# TIPARUL 2: formatul cu X 
	elif [[ "$nume_curat" =~ ^(.*[^0-9])([0-9]+)[xX]([0-9]+)(.*)$ ]]; then
		nume=$(echo "${BASH_REMATCH[1]}" | xargs)
		sezon=$(echo "${BASH_REMATCH[2]}" | xargs)
		episod=$(echo "${BASH_REMATCH[3]}" | xargs)

	# TIPARUL 3: Season X Episode Y
	elif [[ "$nume_curat" =~ ^(.*)[sS]eason[[:space:]]+([0-9]+)[[:space:]]+[eE]pisode[[:space:]]+([0-9]+)(.*)$ ]]; then
		nume=$(echo "${BASH_REMATCH[1]}" | xargs)
		sezon=$(echo "${BASH_REMATCH[2]}" | xargs)
		episod=$(echo "${BASH_REMATCH[3]}" | xargs)

	# TIPARUL 4: SEE
	# spatiu urmat de o cifra, dupa doua cifre, dupa spațiu
	elif [[ "$nume_curat" =~ ^(.*)[[:space:]]([0-9])([0-9]{2})[[:space:]](.*)$ ]]; then
		nume=$(echo "${BASH_REMATCH[1]}" | xargs)
		sezon=$(echo "${BASH_REMATCH[2]}" | xargs)
		episod=$(echo "${BASH_REMATCH[3]}" | xargs)

	# TIPARUL 5: episod simplu, fara sezon
	# sezon implicit 1
	elif [[ "$nume_curat" =~ ^(.*)-[[:space:]]*([0-9]+)[[:space:]]*(.*)$ ]]; then
		local nume_brut_anime=$(echo "${BASH_REMATCH[1]}" | sed -E 's/\[[^]]*\]//g' | xargs)
		nume=$(echo "$nume_brut_anime" | sed 's/-//g' | xargs)
		sezon="1"
		episod=$(echo "${BASH_REMATCH[2]}" | xargs)
	fi

	if [ -n "$nume" ] && [ -n "$sezon" ]; then
		# numerele ai intotdeauna 2 cifre
		local sezon_padded=$(printf "%02d" "$sezon")
		local episod_padded=$(printf "%02d" "$episod")

		local dest_dir="$MEDIA_DIR/Series/$nume/Season $sezon_padded"
		mkdir -p "$dest_dir"

		# "Nume Serial - SXXEYY.extensie"
		local noul_nume="${nume} - S${sezon_padded}E${episod_padded}.${extensie}"
		
		mv "$file" "$dest_dir/$noul_nume"
		scrie_log "SERIAL: S-a mutat '$filename' -> '$dest_dir/$noul_nume'"
		((count_seriale++))
        
	else
		
		local dest_dir_uncategorized="$MEDIA_DIR/Series/Uncategorized"
		mkdir -p "$dest_dir_uncategorized"
		mv "$file" "$dest_dir_uncategorized/"
		scrie_log "SERIAL (NECATEGORIZAT): S-a mutat '$filename' -> '$dest_dir_uncategorized/'"
		((count_seriale++))
	fi
}

proceseaza_muzica() {
	local file="$1"
	local filename=$(basename "$file")
	
	local extensie=$(echo "$filename" | rev | cut -d'.' -f1 | rev | tr '[:upper:]' '[:lower:]')
	local nume_fara_ext=$(echo "$filename" | rev | cut -d'.' -f2- | rev)
	local nume_curat=$(echo "$nume_fara_ext" | tr '._' ' ' | xargs)

	local dest_dir=""
	local noul_nume=""

	# verific separatorul standard -
	if [[ "$nume_curat" =~ ^(.*)-[[:space:]]*(.*)$ ]]; then
		# iau artist fara numarul de la inceput
		local artist=$(echo "${BASH_REMATCH[1]}" | sed -E 's/^[0-9]+[[:space:]]*//' | xargs)
		local titlu=$(echo "${BASH_REMATCH[2]}" | xargs)
		
		dest_dir="$MEDIA_DIR/Music/$artist"
		noul_nume="${titlu}.${extensie}"
		
		scrie_log "MUZICĂ: S-a mutat '$filename' -> '$dest_dir/$noul_nume'"
	else
		# fallback -> Unsure
		dest_dir="$MEDIA_DIR/Music/Unsure"
		noul_nume="${nume_curat}.${extensie}"
		
		scrie_log "MUZICĂ (UNSURE): S-a mutat '$filename' -> '$dest_dir/$noul_nume'"
	fi

	mkdir -p "$dest_dir"
	mv "$file" "$dest_dir/$noul_nume"
	((count_muzica++))
}


proceseaza_restul() {
	local file="$1"
	local filename=$(basename "$file") #doare nume, fara cale absoluta
	local extensie=$(echo "$filename" | rev | cut -d'.' -f1 | rev | tr '[:upper:]' '[:lower:]') #extensia cu litere mici

	if [ -x "$file" ]; #verificam executabil
		then
		mv "$file" "$MEDIA_DIR/Executables/"
		scrie_log "EXECUTABIL (PERMISIUNE DE EXECUȚIE): S-a mutat '$filename' -> '$MEDIA_DIR/Executables/'"
		((count_restul++))
		return
	fi

#verificam document sau alte executabile
	case "$extensie" in
	
		pdf|odt|doc|docx|xls|xlsx|txt|epub)  # !!! adaug extensii pe parcurs daca e necesar !!!
			mv "$file" "$MEDIA_DIR/Documents/"
			scrie_log "DOCUMENT: S-a mutat '$filename' -> '$MEDIA_DIR/Documents/'"
			((count_restul++))
		;;

		exe|msi|deb|dmg|sh)
			mv "$file" "$MEDIA_DIR/Executables/"
			scrie_log "EXECUTABIL (FĂRĂ PERMISIUNE): S-a mutat '$filename' -> '$MEDIA_DIR/Executables/'"
			((count_restul++))
		;;

		*)
			scrie_log "IGNORAT: Extensie necunoscută pentru fișierul '$filename'"
		;;
		
    esac
}

echo "------------------start organizare---------------------------"

while read -r file; do
    
	#unde se afla fisierul
	parent_dir=$(basename "$(dirname "$file")")
    
	case "$parent_dir" in
	
		"Movies")
			proceseaza_film "$file"
			;;
			
		"Series")
            proceseaza_serial "$file"
            ;;

		"Music")
			proceseaza_muzica "$file"
			;;

		"Downloads")
			proceseaza_restul "$file"
			;;
	esac
done < <(find "$DOWNLOADS_DIR" -type f)

echo "------------------final organizare---------------------------"
echo "Filme organizate:    $count_filme"
echo "Seriale organizate:  $count_seriale"
echo "Melodii organizate:  $count_muzica"
echo "Documente/Executabile: $count_restul"
echo "Jurnal detaliat: $LOG_FILE"

scrie_log "Organizare finalizata: Filme [$count_filme], Seriale [$count_seriale], Muzica [$count_muzica], Documente/Executabile [$count_restul]."
