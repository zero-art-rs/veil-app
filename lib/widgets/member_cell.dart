import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zk_notion_app/assets/style.dart';
import 'package:zk_notion_app/assets/theme.dart';

class MemberCellState {
  String imgUrl;
  String name;
  String identifier;

  MemberCellState({
    required this.imgUrl,
    required this.name,
    required this.identifier,
  });
}

class MemberCell extends StatelessWidget {
  final MemberCellState state;

  const MemberCell({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: BoxBorder.all(color: Colors.grey, width: 0.3),
      ),
      child: Row(
        spacing: 12,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.network(
              state.imgUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.name,
                style: GoogleFonts.urbanist(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                state.identifier,
                style: GoogleFonts.urbanist(
                  fontSize: 14,
                  fontWeight: FontWeight.w100,
                ),
              ),
            ],
          ),
          Spacer(),

          SizedBox(
            width: 40,
            height: 40,
            child: ElevatedButton(
              onPressed: () => {},
              style: AppStyles.lightErrorButtonStyle,
              child: Icon(Icons.delete_outline),
            ),
          ),
        ],
      ),
    );
  }
}
