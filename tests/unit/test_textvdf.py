from steamostools.vdf.textvdf import read_braced_section, read_kv_pairs

SAMPLE_CONFIG_VDF = """
"InstallConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"CompatToolMapping"
				{
					"123"
					{
						"name"		"proton_experimental"
						"config"		""
					}
					"456"
					{
						"name"		"GE-Proton9-1"
					}
				}
			}
		}
	}
}
"""


def test_read_braced_section_finds_nested_section():
    body = read_braced_section(SAMPLE_CONFIG_VDF, "CompatToolMapping")
    assert body is not None
    assert '"123"' in body
    assert '"456"' in body


def test_read_braced_section_returns_none_when_missing():
    assert read_braced_section(SAMPLE_CONFIG_VDF, "NoSuchSection") is None


def test_read_braced_section_handles_nested_braces_correctly():
    body = read_braced_section(SAMPLE_CONFIG_VDF, "CompatToolMapping")
    # Must include the inner "123" { ... } block contents, and not cut off early
    assert "proton_experimental" in body
    assert "GE-Proton9-1" in body


def test_read_kv_pairs_extracts_flat_pairs():
    block = '"name"\t"proton_experimental"\n"config"\t""\n'
    pairs = read_kv_pairs(block)
    assert pairs == {"name": "proton_experimental", "config": ""}
