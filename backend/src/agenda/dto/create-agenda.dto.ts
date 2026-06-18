export class CreateAgendaDto {
  title: string;
  startDateTime: string;
  endDateTime: string;
  placeId?: string;
  landmarkId?: number;
  notes?: string;
}
