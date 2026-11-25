"use client";

import { useEffect, useRef, useState } from "react";
import { Button } from "@/components/ui/button";

// Downscale to keep uploads small: longest side ≤ 1024 px, JPEG ~0.85.
async function downscale(blob: Blob, max = 1024, quality = 0.85): Promise<Blob> {
  const bitmap = await createImageBitmap(blob);
  const scale = Math.min(1, max / Math.max(bitmap.width, bitmap.height));
  const w = Math.max(1, Math.round(bitmap.width * scale));
  const h = Math.max(1, Math.round(bitmap.height * scale));
  const canvas = document.createElement("canvas");
  canvas.width = w;
  canvas.height = h;
  canvas.getContext("2d")!.drawImage(bitmap, 0, 0, w, h);
  return await new Promise<Blob>((resolve, reject) =>
    canvas.toBlob(
      (b) => (b ? resolve(b) : reject(new Error("encode failed"))),
      "image/jpeg",
      quality,
    ),
  );
}

export default function PhotoField({
  value,
  onChange,
  onUploadingChange,
}: {
  value: string | null;
  onChange: (url: string | null) => void;
  onUploadingChange?: (uploading: boolean) => void;
}) {
  const fileRef = useRef<HTMLInputElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [cameraOn, setCameraOn] = useState(false);

  const setUploading = (v: boolean) => {
    setBusy(v);
    onUploadingChange?.(v);
  };

  const stopCamera = () => {
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
    setCameraOn(false);
  };

  // Ensure the camera is released if the dialog closes while it's open.
  useEffect(
    () => () => {
      streamRef.current?.getTracks().forEach((t) => t.stop());
    },
    [],
  );

  const upload = async (blob: Blob) => {
    setError(null);
    setUploading(true);
    try {
      const scaled = await downscale(blob);
      const fd = new FormData();
      fd.append("photo", scaled, "photo.jpg");
      const res = await fetch("/api/photos", { method: "POST", body: fd });
      if (!res.ok) {
        const body = (await res.json().catch(() => ({}))) as { error?: string };
        setError(body.error ?? "Upload failed.");
        return;
      }
      const { url } = (await res.json()) as { url: string };
      onChange(url);
    } catch {
      setError("Couldn't process the image.");
    } finally {
      setUploading(false);
    }
  };

  const onFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (f) await upload(f);
    e.target.value = "";
  };

  const startCamera = async () => {
    setError(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: "user" },
      });
      streamRef.current = stream;
      setCameraOn(true);
      requestAnimationFrame(() => {
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          videoRef.current.play().catch(() => {});
        }
      });
    } catch {
      setError("Camera unavailable or permission denied — you can upload a file instead.");
    }
  };

  const capture = async () => {
    const video = videoRef.current;
    if (!video || !video.videoWidth) return;
    const canvas = document.createElement("canvas");
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext("2d")!.drawImage(video, 0, 0);
    stopCamera();
    const blob = await new Promise<Blob>((r) =>
      canvas.toBlob((b) => r(b!), "image/jpeg", 0.95),
    );
    await upload(blob);
  };

  if (value) {
    return (
      <div className="flex items-center gap-3">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={value}
          alt="Cardholder"
          className="size-20 rounded-lg border border-hairline object-cover"
        />
        <Button type="button" variant="outline" size="sm" onClick={() => onChange(null)}>
          Remove
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <input
        ref={fileRef}
        type="file"
        accept="image/*"
        className="sr-only"
        onChange={onFile}
      />
      {cameraOn ? (
        <div className="space-y-2">
          <video
            ref={videoRef}
            className="w-full max-w-xs rounded-lg bg-black"
            muted
            playsInline
          />
          <div className="flex gap-2">
            <Button type="button" size="sm" onClick={capture} disabled={busy}>
              {busy ? "Saving…" : "Capture"}
            </Button>
            <Button type="button" variant="outline" size="sm" onClick={stopCamera}>
              Cancel
            </Button>
          </div>
        </div>
      ) : (
        <div className="flex gap-2">
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={busy}
            onClick={() => fileRef.current?.click()}
          >
            {busy ? "Uploading…" : "Upload photo"}
          </Button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={busy}
            onClick={startCamera}
          >
            Use camera
          </Button>
        </div>
      )}
      {error && (
        <p role="alert" className="text-sm text-destructive">
          {error}
        </p>
      )}
    </div>
  );
}
