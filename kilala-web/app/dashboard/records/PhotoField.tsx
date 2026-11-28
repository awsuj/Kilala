"use client";

import { useEffect, useRef, useState } from "react";
import { ImagePlus, Camera, X } from "lucide-react";
import { Button } from "@/components/ui/button";

// Accepted image types and max size, enforced before upload.
const ACCEPTED_TYPES = ["image/jpeg", "image/png", "image/webp"];
const ACCEPT_ATTR = ACCEPTED_TYPES.join(",");
const MAX_FILE_MB = 8;
const MAX_FILE_BYTES = MAX_FILE_MB * 1024 * 1024;

// Returns an error message if the file isn't an allowed image within size, else null.
function validateFile(file: File): string | null {
  if (!ACCEPTED_TYPES.includes(file.type))
    return "Use a JPG, PNG, or WebP image.";
  if (file.size > MAX_FILE_BYTES)
    return `Image must be ${MAX_FILE_MB} MB or smaller.`;
  return null;
}

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
  const [dragOver, setDragOver] = useState(false);

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

  // Validate then upload — shared by the file picker and drag-and-drop.
  const handleFile = async (f: File) => {
    const invalid = validateFile(f);
    if (invalid) {
      setError(invalid);
      return;
    }
    await upload(f);
  };

  const onFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const f = e.target.files?.[0];
    if (f) await handleFile(f);
    e.target.value = "";
  };

  const onDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    const f = e.dataTransfer.files?.[0];
    if (f) await handleFile(f);
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
      setError(
        "Camera unavailable or permission denied — you can upload a file instead.",
      );
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
        <div className="flex flex-col gap-2">
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => fileRef.current?.click()}
          >
            Replace
          </Button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => {
              setError(null);
              onChange(null);
            }}
          >
            <X className="size-4" /> Clear
          </Button>
        </div>
        <input
          ref={fileRef}
          type="file"
          accept={ACCEPT_ATTR}
          className="sr-only"
          onChange={onFile}
        />
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <input
        ref={fileRef}
        type="file"
        accept={ACCEPT_ATTR}
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
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={stopCamera}
            >
              Cancel
            </Button>
          </div>
        </div>
      ) : (
        <div className="space-y-2">
          <button
            type="button"
            disabled={busy}
            onClick={() => fileRef.current?.click()}
            onDragOver={(e) => {
              e.preventDefault();
              setDragOver(true);
            }}
            onDragLeave={() => setDragOver(false)}
            onDrop={onDrop}
            className={`flex w-full flex-col items-center justify-center gap-1.5 rounded-lg border border-dashed px-4 py-6 text-center transition-colors disabled:cursor-not-allowed disabled:opacity-60 ${
              dragOver
                ? "border-kilala-green bg-kilala-green/5"
                : "border-hairline bg-surface hover:border-kilala-green/60 hover:bg-kilala-green/5"
            }`}
          >
            <ImagePlus
              className="size-5 text-muted-foreground"
              aria-hidden="true"
            />
            <span className="text-sm font-medium text-foreground">
              {busy ? "Uploading…" : "Choose photo to upload"}
            </span>
            <span className="text-xs text-muted-foreground">
              Drag &amp; drop or click · JPG, PNG, or WebP · up to {MAX_FILE_MB}{" "}
              MB
            </span>
          </button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={busy}
            onClick={startCamera}
          >
            <Camera className="size-4" /> Use camera
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
