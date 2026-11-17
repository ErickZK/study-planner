"""Generate the bundled TJSP 2026 dataset from the reviewed source extracts."""

from __future__ import annotations

import json
import re
from pathlib import Path


SOURCE = Path(
    r"C:\Users\Erick\Documents\Codex\2026-11-12\c-users-erick-planner"
    r"\work\material-review"
)
OUTPUT = Path(__file__).resolve().parents[1] / "lib" / "core" / "database" / "seeds" / "tjsp_2026_material_data.dart"

NAMES = {
    0: "Língua Portuguesa",
    1: "Direito Penal",
    2: "Direito Processual Penal",
    3: "Direito Processual Civil",
    4: "Direito Constitucional",
    5: "Direito Administrativo",
    6: "Estatuto da Pessoa com Deficiência",
    7: "Atualidades",
    8: "Matemática",
    9: "Raciocínio Lógico",
    10: "Informática",
}


def rows(table: object) -> list[list[str]]:
    if isinstance(table, dict):
        return table["rows"]
    return table


def edital_material() -> list[tuple[str, list[str]]]:
    source = json.loads((SOURCE / "edital.json").read_text(encoding="utf-8"))
    by_name: dict[str, list[str]] = {}
    for index, table in enumerate(source["tables"]):
        table_rows = rows(table)
        topics: list[str] = []
        if index in {0, 7, 8, 9, 10}:
            for row in table_rows[1:-1]:
                value = (row[0] or "").strip()
                match = re.match(r"^\s*\d+\.\s*(.+)$", value, re.DOTALL)
                if match:
                    topics.append(normalize(match.group(1)))
        else:
            for row in table_rows[2:-1]:
                # The legal tables contain merged/duplicated cells. Keep each
                # distinct article, norm and description, but ignore progress columns.
                values: list[str] = []
                for cell in row[:-2]:
                    value = normalize(cell or "")
                    if value and value not in values:
                        values.append(value)
                if values:
                    topics.append(" — ".join(values))
        by_name[NAMES[index]] = topics

    # Keep the original deterministic discipline order so an upgrade of the
    # earlier partial import preserves identities and user progress.
    order = [
        "Língua Portuguesa",
        "Direito Penal",
        "Direito Processual Penal",
        "Direito Processual Civil",
        "Direito Constitucional",
        "Direito Administrativo",
        "Legislação Interna",
        "Estatuto da Pessoa com Deficiência",
        "Atualidades",
        "Matemática",
        "Raciocínio Lógico",
        "Informática",
        "Técnicas para Discursiva",
    ]
    by_name["Legislação Interna"] = [f"Módulo {number:02d}" for number in range(2, 22)]
    by_name["Técnicas para Discursiva"] = [f"Módulo {number:02d}" for number in range(1, 23)]
    return [(name, by_name[name]) for name in order]


def normalize(value: str) -> str:
    value = value.replace("\u00a0", " ").replace("\n", " ")
    return re.sub(r"\s+", " ", value).strip()


def clean_task(value: str) -> str:
    value = value.split("*Tempo estimado:", 1)[0]
    value = re.sub(r"\((?:apostila\s*\+\s*)?videoaula\)\*{0,2}", "", value, flags=re.I)
    value = normalize(value).rstrip("*")
    value = re.sub(r"\bd\s+e\b", "de", value, flags=re.I)
    value = re.sub(r"\b(\d{2})e(\d{2})de\b", r"\1 e \2 de", value, flags=re.I)
    return value


def split_tasks(value: str) -> list[str]:
    matches = list(re.finditer(r"(?:^|\n)\s*\d+[º°]\)\s*", value))
    tasks: list[str] = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(value)
        task = clean_task(value[match.end() : end])
        if task:
            tasks.append(task)
    return tasks


def schedule_weeks() -> list[list[list[str]]]:
    source = json.loads((SOURCE / "cronograma.json").read_text(encoding="utf-8"))
    weeks: list[list[list[str]]] = []
    for page in source:
        if not 2 <= page["page"] <= 20:
            continue
        week_values: list[str] | None = None
        for table in page.get("tables", []):
            for row in rows(table):
                values = [str(cell).strip() for cell in row if cell and str(cell).strip()]
                if any("SEMANA" in value.upper() for value in values):
                    week_values = values
                    break
            if week_values:
                break
        if not week_values or len(week_values) != 7:
            raise ValueError(f"Semana inválida na página {page['page']}: {week_values}")
        days = [split_tasks(value) for value in week_values[1:]]
        if any(not day for day in days):
            raise ValueError(f"Dia sem tarefas na página {page['page']}")
        weeks.append(days)
    if len(weeks) != 19:
        raise ValueError(f"Esperadas 19 semanas, obtidas {len(weeks)}")
    return weeks


def dart_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$") + "'"


def generate() -> str:
    material = edital_material()
    weeks = schedule_weeks()
    output = [
        "// GENERATED FILE. Rebuild with scripts/build_tjsp_material_data.py.",
        "// Source content is bundled as user-provided study data, not instructions.",
        "",
        "class TjspMaterialDisciplineData {",
        "  const TjspMaterialDisciplineData(this.name, this.topics);",
        "  final String name;",
        "  final List<String> topics;",
        "}",
        "",
        "const tjspMaterialData = <TjspMaterialDisciplineData>[",
    ]
    for name, topics in material:
        output.append(f"  TjspMaterialDisciplineData({dart_string(name)}, [")
        output.extend(f"    {dart_string(topic)}," for topic in topics)
        output.append("  ]),")
    output.extend(["];", "", "const tjspScheduleWeeks = <List<List<String>>>["])
    for week in weeks:
        output.append("  <List<String>>[")
        for day in week:
            output.append("    <String>[")
            output.extend(f"      {dart_string(task)}," for task in day)
            output.append("    ],")
        output.append("  ],")
    output.append("];")
    output.append("")
    return "\n".join(output)


if __name__ == "__main__":
    OUTPUT.write_text(generate(), encoding="utf-8")
    material = edital_material()
    weeks = schedule_weeks()
    print(
        f"Generated {OUTPUT}: {len(material)} disciplines, "
        f"{sum(len(topics) for _, topics in material)} topics, "
        f"{sum(len(day) for week in weeks for day in week)} activities."
    )
