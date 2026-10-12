"use client";

import "leaflet/dist/leaflet.css";
import L from "leaflet";
import { Circle, MapContainer, Marker, TileLayer, Tooltip, useMap } from "react-leaflet";
import { useEffect } from "react";

export interface MapChild {
  id: string;
  name: string;
  color: string;
  lat: number;
  lng: number;
  accuracy: number;
  stale: boolean;
}
export interface MapPlace {
  id: string;
  name: string;
  lat: number;
  lng: number;
  radius: number;
}

const TILE_URL = process.env.NEXT_PUBLIC_MAP_TILE_URL || "https://tile.openstreetmap.org/{z}/{x}/{y}.png";
const ATTRIBUTION = process.env.NEXT_PUBLIC_MAP_ATTRIBUTION || "&copy; OpenStreetMap contributors";

function escapeHtml(s: string) {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
}

function avatar(c: MapChild) {
  const initial = escapeHtml(c.name.trim().charAt(0).toUpperCase() || "?");
  const color = /^#[0-9a-fA-F]{6}$/.test(c.color) ? c.color : "#2563EB";
  return L.divIcon({
    className: "",
    iconSize: [44, 44],
    iconAnchor: [22, 22],
    html: `<div style="width:44px;height:44px;border-radius:50%;background:${color};border:3px solid #fff;box-shadow:0 2px 8px rgba(0,0,0,.25);display:grid;place-items:center;color:#fff;font-weight:800;font-size:18px;opacity:${c.stale ? 0.55 : 1}">${initial}</div>`,
  });
}

function FitBounds({ points, focus }: { points: [number, number][]; focus?: [number, number] | null }) {
  const map = useMap();
  const key = JSON.stringify(points);
  useEffect(() => {
    if (focus) map.setView(focus, 16);
    else if (points.length === 1) map.setView(points[0], 15);
    else if (points.length > 1) map.fitBounds(points, { padding: [60, 60] });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, focus?.[0], focus?.[1]]);
  return null;
}

export default function LiveMap({ kids, places, focus }: { kids: MapChild[]; places: MapPlace[]; focus?: [number, number] | null }) {
  const pts: [number, number][] = kids.map((k) => [k.lat, k.lng]);
  return (
    <MapContainer center={pts[0] ?? [6.9271, 79.8612]} zoom={13} className="h-full w-full" scrollWheelZoom>
      <TileLayer url={TILE_URL} attribution={ATTRIBUTION} maxZoom={19} />
      {places.map((p) => (
        <Circle key={p.id} center={[p.lat, p.lng]} radius={p.radius} pathOptions={{ color: "#1D4ED8", weight: 2, fillOpacity: 0.08 }}>
          <Tooltip>{p.name}</Tooltip>
        </Circle>
      ))}
      {kids.map((k) => (
        <Circle key={`acc-${k.id}`} center={[k.lat, k.lng]} radius={Math.min(k.accuracy, 500)} pathOptions={{ color: k.color, weight: 1, fillOpacity: 0.1 }} />
      ))}
      {kids.map((k) => (
        <Marker key={k.id} position={[k.lat, k.lng]} icon={avatar(k)}>
          <Tooltip direction="top" offset={[0, -20]}>{k.name}</Tooltip>
        </Marker>
      ))}
      <FitBounds points={pts} focus={focus} />
    </MapContainer>
  );
}
