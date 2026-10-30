import { Place } from '../schemas/place';
import { NearbyService } from '../schemas/nearby-service';

export interface PlaceSearchParams {
  city: string;
  category?: string;
  query?: string;
  lat?: number;
  lng?: number;
  radius?: number;
  limit?: number;
}

export interface PlaceNearbyParams {
  latitude: number;
  longitude: number;
  radiusMeters?: number;
  type?: string;
  limit?: number;
}

export interface PlaceDetailsParams {
  placeId: string;
}

export interface PlaceProvider {
  readonly name: string;
  isAvailable(): boolean;
  search(params: PlaceSearchParams): Promise<Place[]>;
  nearby(params: PlaceNearbyParams): Promise<Place[]>;
  details(params: PlaceDetailsParams): Promise<Place | null>;
  searchEmergency(params: PlaceNearbyParams): Promise<NearbyService[]>;
}

export interface PlacesResult<T> {
  data: T;
  provider: string;
  isStale: boolean;
  fetchedAt: string;
}

