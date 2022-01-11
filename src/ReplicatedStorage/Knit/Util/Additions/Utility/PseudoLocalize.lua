--[=[
    Pseudo localizes text. Useful for verifying translation without having
    actual translations available

    @class PseudoLocalize
]=]

local PseudoLocalize = {}

--[=[
    Translates a line into pseudo text while maintaining params
    @param line string -- The line to translate
    @return string -- The translated line
]=]
function PseudoLocalize.PseudoLocalize(Line: string)
	local CharacterMap = PseudoLocalize.PSEUDO_CHARACTER_MAP
	local Output = {}
	local IsParameter = false

	for Start, Stop in utf8.graphemes(Line) do
		local Character = string.sub(Line, Start, Stop)
		if Character == "{" or Character == "[" then
			IsParameter = true
			table.insert(Output, Character)
		elseif Character == "}" or Character == "]" then
			IsParameter = false
			table.insert(Output, Character)
		elseif not IsParameter and CharacterMap[Character] then
			table.insert(Output, CharacterMap[Character])
		else
			table.insert(Output, Character)
		end
	end

	return table.concat(Output)
end

--[=[
    Parses a localization table and adds a pseudo localized locale to the table.

    @param localizationTable LocalizationTable -- LocalizationTable to add to.
    @param preferredLocaleId string? -- Preferred locale to use. Defaults to "qlp-pls"
    @param preferredFromLocale string? -- Preferred from locale. Defaults to "en-us"
    @return string -- The translated line
]=]
function PseudoLocalize.AddToLocalizationTable(LocalizationTable: LocalizationTable, PreferredLocaleId: string?, PreferredFromLocale: string?)
	local LocaleId = PreferredLocaleId or "qlp-pls"
	local FromLocale = PreferredFromLocale or "en"

	local Entries = LocalizationTable:GetEntries()
	for _, Entry in ipairs(Entries) do
		if not Entry.Values[LocaleId] then
			local Line = Entry.Values[FromLocale]
			if Line then
				Entry.Values[LocaleId] = PseudoLocalize.PseudoLocalize(Line)
			else
				warn(string.format("[PseudoLocalize.AddToLocalizationTable] - No entry in key %q for locale %q", Entry.Key, FromLocale))
			end
		end
	end

	LocalizationTable:SetEntries(Entries)
end

--[=[
    Mapping of English characters to pseudo localized characters.

    @prop PSEUDO_CHARACTER_MAP { [string]: string }
    @within PseudoLocalize
]=]
PseudoLocalize.PSEUDO_CHARACTER_MAP = {
	a = "á";
	b = "β";
	c = "ç";
	d = "δ";
	e = "è";
	f = "ƒ";
	g = "ϱ";
	h = "λ";
	i = "ï";
	j = "J";
	k = "ƙ";
	l = "ℓ";
	m = "₥";
	n = "ñ";
	o = "ô";
	p = "ƥ";
	q = "9";
	r = "ř";
	s = "ƨ";
	t = "ƭ";
	u = "ú";
	v = "Ʋ";
	w = "ω";
	x = "ж";
	y = "¥";
	z = "ƺ";
	A = "Â";
	B = "ß";
	C = "Ç";
	D = "Ð";
	E = "É";
	F = "F";
	G = "G";
	H = "H";
	I = "Ì";
	J = "J";
	K = "K";
	L = "£";
	M = "M";
	N = "N";
	O = "Ó";
	P = "Þ";
	Q = "Q";
	R = "R";
	S = "§";
	T = "T";
	U = "Û";
	V = "V";
	W = "W";
	X = "X";
	Y = "Ý";
	Z = "Z";
}

table.freeze(PseudoLocalize)
return PseudoLocalize
