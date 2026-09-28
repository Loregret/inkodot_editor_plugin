using System;
using System.Text;
using System.Text.RegularExpressions;
using Godot;

namespace InkodotEditor;

[GlobalClass, Tool, Icon("uid://mhdwjl1ydy8n")]
public partial class TextFormatter : Resource
{
	[ExportSubgroup("BBCode")]
	[Export] public bool ConvertBBCode = true;

	[ExportSubgroup("Asterisk")]
	[Export] public bool ColorizeAsterisk = true;
	[Export] public Color ColorizeAsteriskColor = Colors.DarkGray;
	[Export] public bool ItalicizeAsterisk = false;

	[ExportSubgroup("Quotation Marks")]
	[Export] public QuotationMarkType CurrentQuotationMarks = QuotationMarkType.Regular;

	public enum QuotationMarkType
	{
		Regular = 1,
		Curly = 2,
		Angular = 3,
	}


	//> Main

	public string GetConvertedText(string text)
	{
		var str = text;

		str = ConvertQuotationMark(str);

		if (ColorizeAsterisk) str = ColorizeAsteriskFormat(str);
		if (ItalicizeAsterisk) str = ItalicizeAsteriskFormat(str);
		if (ConvertBBCode) str = ConvertToBBCode(str); // place at bottom

		return str;
	}


	//> Asterisk

	static string ColorizeAsteriskFormat(string input)
	{
		const string Replacement = "<color=gray>$1</color>";
		return AsteriskRegex.Replace(input, Replacement);
	}

	static string ItalicizeAsteriskFormat(string input)
	{
		const string Replacement = "<i>$1</i>";
		return AsteriskRegex.Replace(input, Replacement);
	}


	//> Quotation Marks

	string ConvertQuotationMark(string input)
	{
		var str = input;

		if (CurrentQuotationMarks == QuotationMarkType.Angular)
		{
			str = QuotationMarksToAngularFormat(str);
		}

		else if (CurrentQuotationMarks == QuotationMarkType.Curly)
		{
			str = QuotationMarksToCurlyFormat(str);
		}

		return str;
	}

	static string QuotationMarkFormat(string input, string opening, string closing)
	{
		// First pass: handle opening quotes
		string result = OpeningQuotationMarkRegex.Replace(input, opening);

		// Second pass: handle closing quotes
		result = ClosingQuotationMarkRegex.Replace(result, closing);

		return result;
	}

	static string QuotationMarksToCurlyFormat(string input)
	{
		const string Opening = "“";
		const string Closing = "”";
		return QuotationMarkFormat(input, Opening, Closing);
	}

	static string QuotationMarksToAngularFormat(string input)
	{
		const string Opening = "«";
		const string Closing = "»";
		return QuotationMarkFormat(input, Opening, Closing);
	}


	//> BBCode

	static string ConvertToBBCode(string text)
	{
		StringBuilder builder = new(text);

		builder.Replace("<", "[");
		builder.Replace(">", "]");

		return builder.ToString();
	}


	//> Regex

	static readonly Regex OpeningQuotationMarkRegex = CompiledOpeningQuotationMarkRegex();
	[GeneratedRegex(@"(?<=(^|\s|\(|\[|{|\p{Pi}))""")] private static partial Regex CompiledOpeningQuotationMarkRegex();

	static readonly Regex ClosingQuotationMarkRegex = CompiledClosingQuotationMarkRegex();
	[GeneratedRegex(@"""(?=($|\s|\.|,|;|:|!|\?|\)|\]|}|\p{Pf}))")] private static partial Regex CompiledClosingQuotationMarkRegex();

	static readonly Regex AsteriskRegex = CompiledAsteriskRegex();
	[GeneratedRegex(@"\*(.*?)\*")] private static partial Regex CompiledAsteriskRegex();
}
