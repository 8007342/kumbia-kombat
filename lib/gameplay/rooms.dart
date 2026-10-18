/// Runtime rooms are enabled only when their art, chart and score are wired.
class PartyRoom {
  const PartyRoom({
    required this.title,
    required this.metric,
    required this.score,
    required this.background,
    required this.challenger,
    required this.leadShape,
    required this.invitation,
  });
  final String title;
  final String metric;
  final String score;
  final String background;
  final String challenger;
  final String leadShape;
  final String invitation;
}

const partyRooms = [
  PartyRoom(
    title: 'THE GARDEN',
    metric: 'MOJO',
    score: 'garden_mojo',
    background: 'garden/garden-mansion.png',
    challenger: 'garden/gatekeeper.png',
    leadShape: 'triangle',
    invitation: 'Mirror the rhythm. Earn your way in.',
  ),
  PartyRoom(
    title: 'THE BAR',
    metric: 'SWAG',
    score: 'bar_swag',
    background: 'bar/bar-interior.png',
    challenger: 'bar/bartender.png',
    leadShape: 'sine',
    invitation: 'The bartender has a rhythm of their own.',
  ),
];
