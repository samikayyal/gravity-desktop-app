import 'package:flutter/material.dart';
import 'package:gravity_desktop_app/custom_widgets/my_text.dart';

class TableContainer extends StatelessWidget {
  final List<String> columnHeaders;
  final List<TableRow> rowData;
  final Map<int, FlexColumnWidth> columnWidths;

  const TableContainer(
      {super.key,
      required this.columnHeaders,
      required this.rowData,
      required this.columnWidths});

  @override
  Widget build(BuildContext context) {
    if (columnHeaders.length != columnWidths.length) {
      throw ArgumentError(
          'Number of column headers must match number of column widths');
    }

    final ScrollController verticalController = ScrollController();

    return Container(
      clipBehavior: Clip.antiAlias, // To clip the child to the border radius
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Scrollbar(
        controller: verticalController,
        thumbVisibility: true,
        thickness: 8,
        radius: const Radius.circular(4),
        child: SingleChildScrollView(
          controller: verticalController,
          scrollDirection: Axis.vertical,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Table(
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                columnWidths: columnWidths,
                children: [
                  // Header Row
                  TableRow(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade400,
                          width: 1.5,
                        ),
                      ),
                    ),
                    children: [
                      ...columnHeaders.map((header) => buildHeaderCell(header)),
                    ],
                  ),
                  // Data Rows
                  ...rowData,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

Widget buildHeaderCell(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    child: Text(
      text,
      style: AppTextStyles.sectionHeaderStyle.copyWith(fontSize: 18),
    ),
  );
}

Widget buildDataCell(String text, {TextStyle? style}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    child: Text(
      text,
      style: style ?? AppTextStyles.regularTextStyle,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

class TableThemes {
  static const evenRowColor = Colors.white;
  static final oddRowColor = Colors.grey.withAlpha(18);
}
