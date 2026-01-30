#!/bin/bash

# Author: Haitham Aouati & Astro
# GitHub: github.com/haithamaouati

# Colors
nc="\e[0m"
bold="\e[1m"
underline="\e[4m"
bold_green="\e[1;32m"
bold_red="\e[1;31m"
bold_yellow="\e[1;33m"

# Dependency check
for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: $cmd is required but not installed." >&2
        exit 1
    fi
done

# Banner
print_banner() {
clear
echo -e "${bold}"
echo -e "    /\\___/\\"
echo -e "    )     ("
echo -e "   =\     /="
echo -e "     )   ("
echo -e "    /     \\   ${bold_green}$0${nc}${bold}"
echo -e "    )     (   ${nc}TikTok User Info Scraper${bold}"
echo -e "   /       \\  ${nc}Author: Haitham Aouati${bold}"
echo -e "   \       /  ${nc}GitHub: ${underline}github.com/haithamaouati${nc}${bold}"
echo -e "    \__ __/"
echo -e "       ))"
echo -e "      //"
echo -e "     (("
echo -e "      \)${nc}\n"
}

print_banner

# Get username from argument
username="${1:-}"
username="${username/@/}"  # Remove @ if included

if [[ -z "$username" ]]; then
    echo -e "Usage: $0 <username>\n"
    exit 1
fi

echo -e "Scraping TikTok info for ${bold}@$username${nc}"



# Fetch source (versión simple, sin rotación ni delays)
url="https://www.tiktok.com/@$username?isUniqueId=true&isSecured=true"
source_code=$(curl -sL -A "Mozilla/5.0" "$url")


# Multi-language output (Spanish/English)
lang_code="${LANG:0:2}"
if [[ "$lang_code" == "es" ]]; then
    MSG_BLOCKED="TikTok está bloqueando la solicitud (captcha o verificación requerida). Intenta de nuevo más tarde o usa una VPN."
    MSG_NOUSER="El usuario @$username no existe en TikTok."
    MSG_NORESPONSE="No se pudo obtener respuesta de TikTok. Puede que la conexión esté bloqueada o haya un problema de red."
    MSG_STRUCTURE="No se encontró la información esperada. Puede que TikTok haya cambiado su estructura interna."
    MSG_WARNING="\n${bold_yellow}ADVERTENCIA:${nc} ¡Posible bloqueo o captcha detectado!\n"
else
    MSG_BLOCKED="TikTok is blocking the request (captcha or verification required). Try again later or use a VPN."
    MSG_NOUSER="User @$username does not exist on TikTok."
    MSG_NORESPONSE="Could not get a response from TikTok. The connection may be blocked or there is a network issue."
    MSG_STRUCTURE="Expected information not found. TikTok may have changed its internal structure."
    MSG_WARNING="\n${bold_yellow}WARNING:${nc} Possible block or captcha detected!\n"
fi

# Error handling: check if TikTok blocks the request or user does not exist
if [[ -z "$source_code" ]]; then
    echo -e "${bold_red}Error:${nc} $MSG_NORESPONSE"
    exit 1
fi

# Detect if TikTok shows a captcha or block page
if echo "$source_code" | grep -qi 'captcha' || echo "$source_code" | grep -qi 'verify your identity'; then
    echo -e "$MSG_WARNING"
    echo -e "${bold_red}Error:${nc} $MSG_BLOCKED"
    exit 1
fi

# Detect if user does not exist
if echo "$source_code" | grep -q '"statusCode":404'; then
    echo -e "${bold_red}Error:${nc} $MSG_NOUSER"
    exit 1
fi

# Detect if the expected data structure is missing (site update)
if ! echo "$source_code" | grep -q 'uniqueId'; then
    echo -e "${bold_red}Error:${nc} $MSG_STRUCTURE"
    exit 1
fi

# Helper to extract JSON fields
extract() {
    echo "$source_code" | grep -oP "$1" | head -n 1 | sed "$2"
}

# Extract main fields
id=$(extract '"id":"\d+"' 's/"id":"//;s/"//')
uniqueId=$(extract '"uniqueId":"[^"]*"' 's/"uniqueId":"//;s/"//')
nickname=$(extract '"nickname":"[^"]*"' 's/"nickname":"//;s/"//')
avatarLarger=$(extract '"avatarLarger":"[^"]*"' 's/"avatarLarger":"//;s/"//')
signature=$(extract '"signature":"[^"]*"' 's/"signature":"//;s/"//')
privateAccount=$(extract '"privateAccount":[^,]*' 's/"privateAccount"://')
secret=$(extract '"secret":[^,]*' 's/"secret"://')
language_code=$(extract '"language":"[^"]*"' 's/"language":"//;s/"//')
secUid=$(extract '"secUid":"[^"]*"' 's/"secUid":"//;s/"//')
diggCount=$(extract '"diggCount":[^,]*' 's/"diggCount"://')
followerCount=$(extract '"followerCount":[^,]*' 's/"followerCount"://')
followingCount=$(extract '"followingCount":[^,]*' 's/"followingCount"://')
heartCount=$(extract '"heartCount":[^,]*' 's/"heartCount"://')
videoCount=$(extract '"videoCount":[^,]*' 's/"videoCount"://')
friendCount=$(extract '"friendCount":[^,}]*' 's/"friendCount"://')  # fix trailing }
createTime=$(extract '"createTime":\d+' 's/"createTime"://')
uniqueIdModifyTime=$(extract '"uniqueIdModifyTime":\d+' 's/"uniqueIdModifyTime"://')
nickNameModifyTime=$(extract '"nickNameModifyTime":\d+' 's/"nickNameModifyTime"://')

# Convert Unix timestamps to human-readable
to_date() {
    if [[ -n "$1" && "$1" =~ ^[0-9]+$ ]]; then
        date -d @"$1" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$1"
    else
        echo "N/A"
    fi
}

createTime_human=$(to_date "$createTime")
uniqueIdModifyTime_human=$(to_date "$uniqueIdModifyTime")
nickNameModifyTime_human=$(to_date "$nickNameModifyTime")

# Resolve language
if [[ -n ${language_code:-} && -f languages.json ]]; then
    language_name=$(jq -r --arg lang "$language_code" '.[] | select(.code == $lang) | .name' languages.json)
    language="${language_name:-Unknown (Code: $language_code)}"
else
    language="N/A"
fi


# Resolve region and country
region_code=$(echo "$source_code" | grep -oP '"ttSeller":false,"region":"\K[^"]+')
if [[ -n "$region_code" && -f countries.json ]]; then
    country_json=$(jq -r --arg region "$region_code" '.[] | select(.code == $region)' countries.json)
    country_name=$(echo "$country_json" | jq -r '.name')
    country_flag=$(echo "$country_json" | jq -r '.emoji')
    if [[ -n "$country_name" && "$country_name" != "null" ]]; then
        pais="$country_name $country_flag"
    else
        pais="Desconocido (Código: $region_code)"
    fi
else
    pais="N/A"
fi


# Extract associated social media (Instagram, YouTube, Twitter)
instagram=$(echo "$source_code" | grep -oP '"instagramName":"\K[^"]*' | head -n 1)
youtube=$(echo "$source_code" | grep -oP '"youtubeChannelId":"\K[^"]*' | head -n 1)
twitter=$(echo "$source_code" | grep -oP '"twitterName":"\K[^"]*' | head -n 1)

# Format social media output
social_output=""
if [[ -n "$instagram" ]]; then
    social_output+="Instagram: https://instagram.com/$instagram\n"
fi
if [[ -n "$youtube" ]]; then
    social_output+="YouTube: https://www.youtube.com/channel/$youtube\n"
fi
if [[ -n "$twitter" ]]; then
    social_output+="Twitter: https://twitter.com/$twitter\n"
fi



# Output in selected language
if [[ -n $id ]]; then
    echo
    if [[ "$lang_code" == "es" ]]; then
        echo "ID de usuario: $id"
        echo "Nombre de usuario: $uniqueId"
        echo "Apodo: $nickname"
        echo "Verificado: $secret"
        echo "Cuenta privada: $privateAccount"
        echo "Idioma: $language"
        echo "País: $pais"
        echo "Seguidores: $followerCount"
        echo "Siguiendo: $followingCount"
        echo "Me gusta: $heartCount"
        echo "Videos: $videoCount"
        echo "Amigos: $friendCount"
        echo "Corazones: $heartCount"
        echo "Digg Count: $diggCount"
        echo "SecUid: $secUid"
        if [[ -n "$social_output" ]]; then
            echo
            echo -e "Redes sociales asociadas:\n$social_output"
        fi
        echo
        echo "Biografía:"
        echo -e "$signature"
        echo
        echo "Cuenta creada: $createTime_human"
        echo "Último cambio de usuario: $uniqueIdModifyTime_human"
        echo "Último cambio de apodo: $nickNameModifyTime_human"
        echo
        echo -e "Perfil de TikTok: ${underline}https://tiktok.com/@$uniqueId${nc}\n"
    else
        echo "User ID: $id"
        echo "Username: $uniqueId"
        echo "Nickname: $nickname"
        echo "Verified: $secret"
        echo "Private Account: $privateAccount"
        echo "Language: $language"
        echo "Country: $pais"
        echo "Followers: $followerCount"
        echo "Following: $followingCount"
        echo "Likes: $heartCount"
        echo "Videos: $videoCount"
        echo "Friends: $friendCount"
        echo "Heart: $heartCount"
        echo "Digg Count: $diggCount"
        echo "SecUid: $secUid"
        if [[ -n "$social_output" ]]; then
            echo
            echo -e "Associated social media:\n$social_output"
        fi
        echo
        echo "Biography:"
        echo -e "$signature"
        echo
        echo "Account Created: $createTime_human"
        echo "Last Username Change: $uniqueIdModifyTime_human"
        echo "Last Nickname Change: $nickNameModifyTime_human"
        echo
        echo -e "TikTok profile: ${underline}https://tiktok.com/@$uniqueId${nc}\n"
    fi
else
    if [[ "$lang_code" == "es" ]]; then
        echo "No se pudieron obtener los detalles de la cuenta. TikTok podría estar bloqueando la solicitud o el usuario no existe."
    else
        echo "Failed to fetch account details. TikTok might block the request or username doesn't exist."
    fi
    exit 1
fi
