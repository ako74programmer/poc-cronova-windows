import xml.etree.ElementTree as ET


def normalize_pom_xml(pom_xml):
    if not isinstance(pom_xml, str):
        raise ValueError("AI returned pom_xml that is not a string")
    try:
        ET.fromstring(pom_xml)
        return pom_xml
    except ET.ParseError as original_error:
        normalized = (
            pom_xml.replace(r"\r\n", "\r\n")
            .replace(r"\n", "\n")
            .replace(r"\r", "\r")
            .replace(r"\t", "\t")
        )
        if normalized == pom_xml:
            raise ValueError(f"AI returned invalid pom_xml: {original_error}") from original_error
        try:
            ET.fromstring(normalized)
        except ET.ParseError as normalized_error:
            raise ValueError(
                "AI returned invalid pom_xml after escaped-whitespace normalization: "
                f"{normalized_error} (original error: {original_error})"
            ) from normalized_error
        print(
            "Normalized literal escaped whitespace in AI-generated pom.xml after XML validation."
        )
        return normalized
