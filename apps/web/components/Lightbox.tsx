"use client";

import { useEffect, useState, type ReactNode } from "react";

/// Lightbox ala NN/g "big photos when requested": ketuk foto untuk
/// melihat versi besar (minimal 2x area tampil). Tanpa lib tambahan.
export function Zoomable({
  src,
  alt,
  label,
  children,
}: {
  src: string;
  alt: string;
  label: string;
  children: ReactNode;
}) {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (!open) return;
    const close = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    document.addEventListener("keydown", close);
    return () => document.removeEventListener("keydown", close);
  }, [open ]);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label={label}
        className="block w-full cursor-zoom-in bg-transparent p-0"
      >
        {children}
      </button>
      {open ? (
        <div
          role="dialog"
          aria-modal="true"
          aria-label={alt}
          onClick={() => setOpen(false)}
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/85 p-4"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={src}
            alt={alt}
            className="max-h-[90vh] max-w-full rounded-xl object-contain"
          />
        </div>
      ) : null}
    </>
  );
}
