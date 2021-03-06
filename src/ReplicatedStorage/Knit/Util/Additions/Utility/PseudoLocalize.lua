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
	a = "??";
	b = "??";
	c = "??";
	d = "??";
	e = "??";
	f = "??";
	g = "??";
	h = "??";
	i = "??";
	j = "J";
	k = "??";
	l = "???";
	m = "???";
	n = "??";
	o = "??";
	p = "??";
	q = "9";
	r = "??";
	s = "??";
	t = "??";
	u = "??";
	v = "??";
	w = "??";
	x = "??";
	y = "??";
	z = "??";
	A = "??";
	B = "??";
	C = "??";
	D = "??";
	E = "??";
	F = "F";
	G = "G";
	H = "H";
	I = "??";
	J = "J";
	K = "K";
	L = "??";
	M = "M";
	N = "N";
	O = "??";
	P = "??";
	Q = "Q";
	R = "R";
	S = "??";
	T = "T";
	U = "??";
	V = "V";
	W = "W";
	X = "X";
	Y = "??";
	Z = "Z";
}

table.freeze(PseudoLocalize)
return PseudoLocalize
