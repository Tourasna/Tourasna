String imageForCategory(String category) {
  switch (category) {
    case "Outdoor Activities":
      return "assets/images/outdooractivities.jpg";
    case "Museums":
      return "assets/images/musuems.jpg";
    case "Shopping":
      return "assets/images/shopping.jpg";
    case "Nature & Parks":
      return "assets/images/naturenparks.jpg";
    case "Sights & Landmarks":
      return "assets/images/sitesnlandmarks.jpg";
    case "Concerts & Shows":
      return "assets/images/concertsnshows.jpg";
    case "Zoos & Aquariums":
      return "assets/images/zoonaquirium.jpg";
    case "Water & Amusement Parks":
      return "assets/images/waternamusementparks.jpg";
    case "Fun & Games":
      return "assets/images/FunNGames.jpg";
    default:
      return "assets/images/personalized.png";
  }
}
