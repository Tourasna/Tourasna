export class PlaceResponseDto {
  id: string;
  name: string;
  description: string | null;
  category: string | null;
  lat: number | null;
  lng: number | null;
  image_url: string | null;
  glb_url: string | null;
  ml_label: string;
}
