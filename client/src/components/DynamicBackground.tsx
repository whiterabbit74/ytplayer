import { useMemo } from "react";

interface DynamicBackgroundProps {
  imageUrl: string;
}

export function DynamicBackground({ imageUrl }: DynamicBackgroundProps) {
  // Use useMemo to avoid re-rendering these unless the image changes
  const blobs = useMemo(() => {
    return [
      { id: 1, size: "80vh", left: "-10%", top: "10%", duration: "25s", delay: "0s" },
      { id: 2, size: "60vh", right: "0%", top: "-10%", duration: "30s", delay: "-5s" },
      { id: 3, size: "70vh", left: "20%", bottom: "-10%", duration: "20s", delay: "-10s" },
    ];
  }, []);

  return (
    <div className="fixed inset-0 overflow-hidden pointer-events-none -z-10 bg-black">
      <div 
        className="absolute inset-0 opacity-40 blur-[100px] scale-110"
        style={{
          backgroundImage: `url(${imageUrl})`,
          backgroundSize: "cover",
          backgroundPosition: "center",
        }}
      />
      
      {blobs.map((blob) => (
        <div
          key={blob.id}
          className="absolute rounded-full opacity-30 blur-[80px] mix-blend-screen"
          style={{
            width: blob.size,
            height: blob.size,
            left: blob.left,
            top: blob.top,
            right: blob.right,
            bottom: blob.bottom,
            backgroundImage: `url(${imageUrl})`,
            backgroundSize: "200% 200%",
            backgroundPosition: "center",
            animation: `drift ${blob.duration} ease-in-out infinite alternate ${blob.delay}`,
          }}
        />
      ))}

      <div className="absolute inset-0 backdrop-blur-2xl bg-black/40" />
      
      <style>{`
        @keyframes drift {
          from { transform: translate(0, 0) rotate(0deg) scale(1); }
          to { transform: translate(10%, 15%) rotate(15deg) scale(1.1); }
        }
      `}</style>
    </div>
  );
}
