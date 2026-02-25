import { useState, useRef, useEffect } from 'react';
import {
  LiveKitRoom,
  useLocalParticipant,
  useDataChannel,
  VideoTrack,
  AudioTrack,
  useTracks,
} from '@livekit/components-react';
import { Track } from 'livekit-client';
import '@livekit/components-styles';

const LANG = {
  th: {
    title: 'Oboon ยืนยันตัวตน',
    scanning: 'กำลังสแกนใบหน้า...',
    joining: 'กำลังเข้าร่วม...',
    noCamera: 'ไม่พบภาพจากกล้อง',
    regFail: 'การลงทะเบียนล้มเหลว',
    noToken: 'ไม่พบโทเค็น',
    joinBtn: '🔐 สแกนใบหน้าและเข้าร่วมสาย',
    processing: 'กำลังประมวลผล...',
    code: 'รหัส',
    // Notifications (keyed by agent message type prefix)
    notif: {
      faceMatch:    '✅ ยืนยันตัวตนสำเร็จ: ใบหน้าตรงกัน!',
      faceMismatch: '⚠️ คำเตือน: ใบหน้าไม่ตรงกับที่ลงทะเบียนไว้!',
      noFace:       '⚠️ คำเตือน: ไม่พบใบหน้าในกล้อง!',
      nsfw:         '🚨 คำเตือน: พบเนื้อหาที่ไม่เหมาะสม (NSFW)!',
    },
  },
  en: {
    title: 'Oboon Face Verification',
    scanning: 'Scanning face...',
    joining: 'Joining...',
    noCamera: 'No camera image found',
    regFail: 'Registration failed',
    noToken: 'Token not found',
    joinBtn: '🔐 Scan Face & Join Call',
    processing: 'Processing...',
    code: 'ID',
    notif: {
      faceMatch:    '✅ Identity verified: Face matched!',
      faceMismatch: '⚠️ Warning: Face does not match registered profile!',
      noFace:       '⚠️ Warning: No face detected in camera!',
      nsfw:         '🚨 Warning: Inappropriate content detected (NSFW)!',
    },
  },
};

function generateId() {
  return 'user-' + Math.random().toString(36).substring(2, 8);
}

export default function App() {
  const [userId] = useState(() => generateId());
  const [token, setToken] = useState('');
  const [serverUrl, setServerUrl] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [status, setStatus] = useState('');
  const [lang, setLang] = useState<'th' | 'en'>('th');
  const t = LANG[lang];
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);

  useEffect(() => {
    navigator.mediaDevices.getUserMedia({ video: { facingMode: 'user' }, audio: false })
      .then(stream => {
        streamRef.current = stream;
        if (videoRef.current) {
          videoRef.current.srcObject = stream;
          videoRef.current.play();
        }
      }).catch(err => setStatus(`Camera: ${err.message}`));
    return () => { streamRef.current?.getTracks().forEach(t => t.stop()); };
  }, []);

  const captureImage = () => {
    if (!videoRef.current) return null;
    const canvas = document.createElement('canvas');
    canvas.width = videoRef.current.videoWidth || 640;
    canvas.height = videoRef.current.videoHeight || 480;
    canvas.getContext('2d')?.drawImage(videoRef.current, 0, 0);
    return canvas.toDataURL('image/jpeg', 0.8);
  };

  const handleJoin = async () => {
    setIsLoading(true);
    setStatus(t.scanning);
    try {
      const image = captureImage();
      if (!image) throw new Error(t.noCamera);

      const regRes = await fetch('/api/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: userId, image })
      });
      const regData = await regRes.json();
      if (!regData.success) throw new Error(regData.detail || t.regFail);

      setStatus(t.joining);
      streamRef.current?.getTracks().forEach(t => t.stop());

      const tokenRes = await fetch(`/api/token?user_id=${encodeURIComponent(userId)}&room=demo-room`);
      const tokenData = await tokenRes.json();
      if (!tokenData.token) throw new Error(t.noToken);

      setToken(tokenData.token);
      setServerUrl(tokenData.url);
      setStatus('');
    } catch (err: any) {
      setStatus(err.message);
      setIsLoading(false);
    }
  };

  if (token && serverUrl) {
    return (
      <LiveKitRoom
        video={true} audio={true}
        token={token} serverUrl={serverUrl}
        connect={true}
        style={{ height: '100dvh', width: '100vw' }}
      >
        <CallUI lang={lang} />
      </LiveKitRoom>
    );
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* Camera */}
      <video
        ref={videoRef}
        muted playsInline
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', objectFit: 'cover', transform: 'scaleX(-1)', zIndex: 1 }}
      />

      {/* Gradient overlay */}
      <div style={{
        position: 'absolute', inset: 0, zIndex: 2,
        background: 'linear-gradient(to bottom, rgba(0,0,0,0.6) 0%, rgba(0,0,0,0) 40%, rgba(0,0,0,0) 60%, rgba(0,0,0,0.7) 100%)',
        pointerEvents: 'none'
      }} />

      {/* Top text */}
      <div style={{ position: 'relative', zIndex: 3, padding: '48px 24px 16px', textAlign: 'center' }}>
        <div style={{ color: '#fff', fontSize: 22, fontWeight: 700, letterSpacing: -0.5 }}>{t.title}</div>
        <div style={{ color: 'rgba(255,255,255,0.55)', fontSize: 13, marginTop: 4, fontFamily: 'monospace' }}>{t.code}: {userId}</div>
        {/* Language toggle */}
        <button
          onClick={() => setLang(l => l === 'th' ? 'en' : 'th')}
          style={{
            marginTop: 10,
            background: 'rgba(255,255,255,0.15)',
            border: '1px solid rgba(255,255,255,0.3)',
            borderRadius: 99,
            color: '#fff',
            fontSize: 12,
            fontWeight: 600,
            padding: '4px 14px',
            cursor: 'pointer',
            backdropFilter: 'blur(8px)',
            letterSpacing: 0.5,
          }}
        >
          {lang === 'th' ? '🇬🇧 EN' : '🇹🇭 ไทย'}
        </button>
      </div>

      {/* Face guide */}
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', zIndex: 3, pointerEvents: 'none' }}>
        <div style={{ position: 'relative', width: 200, height: 260 }}>

          {/* Pulsing glow ring */}
          <div style={{
            position: 'absolute', inset: -10,
            borderRadius: 130,
            border: isLoading ? '2px solid rgba(99,220,255,0.5)' : '2px solid rgba(255,255,255,0.15)',
            animation: isLoading ? 'pulse-ring 1.2s ease-in-out infinite' : 'none',
          }} />

          {/* Oval border — solid when loading, dashed when idle */}
          <div style={{
            position: 'absolute', inset: 0,
            borderRadius: 120,
            border: isLoading
              ? '3px solid rgba(99,220,255,0.9)'
              : '3px dashed rgba(255,255,255,0.45)',
            boxShadow: isLoading ? '0 0 24px rgba(99,220,255,0.4)' : 'none',
            transition: 'border 0.3s, box-shadow 0.3s',
          }} />

          {/* Corner accent marks (4 corners) */}
          {[
            { top: 0, left: 0, borderTop: '3px solid #fff', borderLeft: '3px solid #fff', borderTopLeftRadius: 8 },
            { top: 0, right: 0, borderTop: '3px solid #fff', borderRight: '3px solid #fff', borderTopRightRadius: 8 },
            { bottom: 0, left: 0, borderBottom: '3px solid #fff', borderLeft: '3px solid #fff', borderBottomLeftRadius: 8 },
            { bottom: 0, right: 0, borderBottom: '3px solid #fff', borderRight: '3px solid #fff', borderBottomRightRadius: 8 },
          ].map((s, i) => (
            <div key={i} style={{ position: 'absolute', width: 20, height: 20, ...s }} />
          ))}

          {/* Scanning line (only when loading) */}
          {isLoading && (
            <div style={{
              position: 'absolute', left: 4, right: 4, height: 2,
              background: 'linear-gradient(to right, transparent, rgba(99,220,255,0.9), transparent)',
              borderRadius: 2,
              animation: 'scan-line 1.8s ease-in-out infinite',
              boxShadow: '0 0 8px rgba(99,220,255,0.8)',
            }} />
          )}
        </div>

        {/* Keyframe styles injected inline */}
        <style>{`
          @keyframes pulse-ring {
            0%, 100% { transform: scale(1); opacity: 0.5; }
            50% { transform: scale(1.06); opacity: 1; }
          }
          @keyframes scan-line {
            0% { top: 10px; opacity: 0; }
            10% { opacity: 1; }
            90% { opacity: 1; }
            100% { top: 250px; opacity: 0; }
          }
        `}</style>
      </div>

      {/* Bottom */}
      <div style={{ position: 'relative', zIndex: 3, padding: '16px 32px 48px', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
        {/* Status ticker */}
        {isLoading ? (
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            color: 'rgba(99,220,255,0.95)', fontSize: 13, fontWeight: 600,
            background: 'rgba(0,0,0,0.55)', padding: '6px 16px', borderRadius: 99,
          }}>
            <span style={{ animation: 'blink 1s step-start infinite' }}>●</span>
            {status || t.processing}
            <style>{`@keyframes blink { 0%,100%{opacity:1} 50%{opacity:0} }`}</style>
          </div>
        ) : status ? (
          <div style={{ color: '#f87171', fontSize: 13, background: 'rgba(0,0,0,0.55)', padding: '6px 16px', borderRadius: 99, textAlign: 'center' }}>
            {status}
          </div>
        ) : null}
        <button
          onClick={handleJoin}
          disabled={isLoading}
          style={{
            width: '100%', maxWidth: 320, padding: '18px 0', borderRadius: 16,
            background: isLoading ? 'rgba(255,255,255,0.7)' : '#fff',
            color: '#000', fontSize: 16, fontWeight: 700, border: 'none', cursor: isLoading ? 'not-allowed' : 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            boxShadow: '0 8px 32px rgba(0,0,0,0.5)',
          }}
        >
          {isLoading ? `${status || t.processing}` : t.joinBtn}
        </button>
      </div>

    </div>
  );
}

function CallUI({ lang }: { lang: 'th' | 'en' }) {
  const [alert, setAlert] = useState<{message: string, type: string} | null>(null);
  const { localParticipant } = useLocalParticipant();
  const [micOn, setMicOn] = useState(true);
  const [showSettings, setShowSettings] = useState(false);
  const [isFront, setIsFront] = useState(true);
  const [settings, setSettings] = useState({
    nsfw_threshold: 0.5,
    face_threshold: 0.85,
    sample_rate: 1,
  });

  const t = LANG[lang];

  // Map agent message → translated string based on type tag in payload
  const translateNotif = (payload: { type: string; message: string }) => {
    const n = t.notif;
    const msg = payload.message;
    if (payload.type === 'success') return n.faceMatch;
    if (msg.includes('NSFW') || msg.includes('ไม่เหมาะสม')) return n.nsfw;
    if (msg.includes('ไม่ตรง') || msg.includes('does not match') || msg.includes('IMPOSTER')) return n.faceMismatch;
    return n.noFace;
  };

  // Load settings on mount
  useEffect(() => {
    fetch('/api/settings').then(r => r.json()).then(setSettings).catch(() => {});
  }, []);

  const updateSetting = async (key: string, value: number) => {
    const next = { ...settings, [key]: value };
    setSettings(next);
    try {
      await fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ [key]: value }),
      });
    } catch (e) {}
  };

  const allVideoTracks = useTracks([Track.Source.Camera]);
  const localVideoTrack = allVideoTracks.find(t => t.participant === localParticipant);
  const firstRemoteVideo = allVideoTracks.find(t => t.participant !== localParticipant);

  const allAudioTracks = useTracks([Track.Source.Microphone]);
  const remoteAudioTracks = allAudioTracks.filter(t => t.participant !== localParticipant);

  useDataChannel((msg) => {
    try {
      const payload = JSON.parse(new TextDecoder().decode(msg.payload));
      if (payload.type === 'alert' || payload.type === 'success') {
        setAlert({ message: translateNotif(payload), type: payload.type });
        setTimeout(() => setAlert(null), 3000);
      }
    } catch (e) {}
  });

  const toggleMic = () => {
    localParticipant.setMicrophoneEnabled(!micOn);
    setMicOn(!micOn);
  };

  const toggleCamera = async () => {
    try {
      const next = !isFront;
      // Filter publications to find the camera
      const publications = Array.from(localParticipant.trackPublications.values());
      const camPub = publications.find(p => p.source === Track.Source.Camera);
      
      if (camPub && camPub.videoTrack) {
        // @ts-ignore
        await camPub.videoTrack.restartTrack({
          facingMode: next ? 'user' : 'environment'
        });
        setIsFront(next);
      } else {
        // Fallback: cycle camera via setCameraEnabled
        await localParticipant.setCameraEnabled(true, {
          facingMode: next ? 'user' : 'environment'
        });
        setIsFront(next);
      }
    } catch (e) {
      console.error('Camera switch failed:', e);
    }
  };

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#000', overflow: 'hidden' }}>
      {/* Full screen local video */}
      <div style={{ position: 'absolute', inset: 0, zIndex: 1 }}>
        {localVideoTrack ? (
          <VideoTrack trackRef={localVideoTrack} style={{ width: '100%', height: '100%', objectFit: 'cover', transform: isFront ? 'scaleX(-1)' : 'none' }} />
        ) : (
          <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <span style={{ fontSize: 64 }}>👤</span>
          </div>
        )}
      </div>

      {/* PIP — top left like FaceTime */}
      <div style={{
        position: 'absolute', top: 48, left: 16,
        width: 110, height: 150,
        borderRadius: 16, overflow: 'hidden',
        border: '2px solid rgba(255,255,255,0.3)',
        boxShadow: '0 8px 32px rgba(0,0,0,0.6)',
        background: '#1c1c1e',
        zIndex: 10,
      }}>
        {firstRemoteVideo ? (
          <VideoTrack trackRef={firstRemoteVideo} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
        ) : (
          <div style={{ width: '100%', height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4 }}>
            <span style={{ fontSize: 28 }}>🤖</span>
            <span style={{ color: 'rgba(255,255,255,0.4)', fontSize: 10, textAlign: 'center', padding: '0 4px' }}>AI Agent</span>
          </div>
        )}
        {firstRemoteVideo?.participant && (
          <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, background: 'rgba(0,0,0,0.5)', color: '#fff', fontSize: 10, textAlign: 'center', padding: '2px 4px' }}>
            {firstRemoteVideo.participant.identity}
          </div>
        )}
      </div>

      {/* Remote audio */}
      {remoteAudioTracks.map(t => (
        <AudioTrack key={t.publication?.trackSid || t.participant.identity} trackRef={t} />
      ))}

      {/* Alert banner */}
      {alert && (
        <div style={{
          position: 'absolute', top: 24, left: 16, right: 16, zIndex: 30,
          background: alert.type === 'success' ? '#10b981' : '#dc2626',
          color: '#fff', fontWeight: 700, fontSize: 14,
          padding: '12px 20px', borderRadius: 16, textAlign: 'center',
          boxShadow: `0 8px 32px ${alert.type === 'success' ? 'rgba(16,185,129,0.5)' : 'rgba(220,38,38,0.5)'}`,
          border: `2px solid ${alert.type === 'success' ? '#34d399' : '#ef4444'}`,
          animation: alert.type === 'success' ? 'none' : 'bounce 1s infinite',
        }}>
          {alert.message}
        </div>
      )}

      {/* Settings Panel */}
      {showSettings && (
        <div style={{
          position: 'absolute', bottom: 130, left: 16, right: 16, zIndex: 25,
          background: 'rgba(20,20,20,0.92)', backdropFilter: 'blur(20px)',
          borderRadius: 20, padding: '20px 24px',
          border: '1px solid rgba(255,255,255,0.12)',
          boxShadow: '0 16px 48px rgba(0,0,0,0.6)',
        }}>
          <div style={{ color: '#fff', fontWeight: 700, fontSize: 15, marginBottom: 16 }}>⚙️ ตั้งค่า AI</div>

          {/* NSFW threshold */}
          <div style={{ marginBottom: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <span style={{ color: 'rgba(255,255,255,0.8)', fontSize: 13 }}>🚨 ความไวต่อ NSFW</span>
              <span style={{ color: '#f87171', fontSize: 13, fontWeight: 700 }}>
                {settings.nsfw_threshold <= 0.35 ? 'สูงมาก' : settings.nsfw_threshold <= 0.5 ? 'สูง' : settings.nsfw_threshold <= 0.7 ? 'ปานกลาง' : 'ต่ำ'}
                {' '}({settings.nsfw_threshold.toFixed(2)})
              </span>
            </div>
            <input type="range" min="0.1" max="0.9" step="0.05"
              value={settings.nsfw_threshold}
              onChange={e => updateSetting('nsfw_threshold', parseFloat(e.target.value))}
              style={{ width: '100%', accentColor: '#f87171' }}
            />
            <div style={{ display: 'flex', justifyContent: 'space-between', color: 'rgba(255,255,255,0.35)', fontSize: 10, marginTop: 2 }}>
              <span>ไวมาก (0.1)</span><span>ไม่ไว (0.9)</span>
            </div>
          </div>

          {/* Face threshold */}
          <div style={{ marginBottom: 16 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <span style={{ color: 'rgba(255,255,255,0.8)', fontSize: 13 }}>👤 ความเข้มงวดจดจำใบหน้า</span>
              <span style={{ color: '#60a5fa', fontSize: 13, fontWeight: 700 }}>
                {settings.face_threshold >= 0.9 ? 'หลวม' : settings.face_threshold >= 0.75 ? 'ปานกลาง' : 'เข้มงวด'}
                {' '}({settings.face_threshold.toFixed(2)})
              </span>
            </div>
            <input type="range" min="0.5" max="1.0" step="0.05"
              value={settings.face_threshold}
              onChange={e => updateSetting('face_threshold', parseFloat(e.target.value))}
              style={{ width: '100%', accentColor: '#60a5fa' }}
            />
            <div style={{ display: 'flex', justifyContent: 'space-between', color: 'rgba(255,255,255,0.35)', fontSize: 10, marginTop: 2 }}>
              <span>เข้มงวด (0.5)</span><span>หลวม (1.0)</span>
            </div>
          </div>

          {/* Sample rate */}
          <div>
            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
              <span style={{ color: 'rgba(255,255,255,0.8)', fontSize: 13 }}>⚡ ความถี่วิเคราะห์</span>
              <span style={{ color: '#a78bfa', fontSize: 13, fontWeight: 700 }}>ทุก {settings.sample_rate}s</span>
            </div>
            <input type="range" min="0.5" max="10" step="0.5"
              value={settings.sample_rate}
              onChange={e => updateSetting('sample_rate', parseFloat(e.target.value))}
              style={{ width: '100%', accentColor: '#a78bfa' }}
            />
            <div style={{ display: 'flex', justifyContent: 'space-between', color: 'rgba(255,255,255,0.35)', fontSize: 10, marginTop: 2 }}>
              <span>เร็ว (0.5s)</span><span>ช้า (10s)</span>
            </div>
          </div>
        </div>
      )}

      {/* Bottom controls */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0, zIndex: 20,
        display: 'flex', justifyContent: 'center', gap: 16, padding: '24px 0 48px',
        background: 'linear-gradient(to top, rgba(0,0,0,0.7), transparent)',
      }}>
        <button
          onClick={toggleMic}
          style={{
            width: 54, height: 54, borderRadius: 27,
            background: micOn ? 'rgba(255,255,255,0.2)' : '#ef4444',
            border: 'none', cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 22, backdropFilter: 'blur(10px)',
            boxShadow: micOn ? 'none' : '0 4px 20px rgba(239,68,68,0.5)',
          }}
        >
          {micOn ? '🎙️' : '🔇'}
        </button>

        <button
          onClick={toggleCamera}
          style={{
            width: 54, height: 54, borderRadius: 27,
            background: 'rgba(255,255,255,0.2)',
            border: 'none', cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 22, backdropFilter: 'blur(10px)',
          }}
        >
          🔄
        </button>

        <button
          onClick={() => setShowSettings(s => !s)}
          style={{
            width: 54, height: 54, borderRadius: 27,
            background: showSettings ? 'rgba(167,139,250,0.4)' : 'rgba(255,255,255,0.2)',
            border: showSettings ? '2px solid #a78bfa' : '2px solid transparent',
            cursor: 'pointer',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 22, backdropFilter: 'blur(10px)',
          }}
        >
          ⚙️
        </button>
      </div>
    </div>
  );
}
