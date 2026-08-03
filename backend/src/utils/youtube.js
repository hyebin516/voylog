function extractYoutubeVideoId(youtubeUrl) {
  const match = youtubeUrl.match(/(?:v=|youtu\.be\/)([\w-]{11})/);
  return match ? match[1] : null;
}

module.exports = { extractYoutubeVideoId };
