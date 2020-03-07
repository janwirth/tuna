# allow elm to open windows of any kind of URL
sed -i "s/A2(\$elm\$core\$String\$startsWith, 'http:\/\/', str)/true/" elm-stuff/elm.js
