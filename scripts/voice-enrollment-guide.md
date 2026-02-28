# Voice Enrollment Recording Guide

Record your voice samples to teach the system to recognize you.
Each sample should be **5-15 seconds** of just YOUR voice (no one else).

## Recording Instructions

Use your **iPhone** (Voice Memos app or any recorder) — this matches the device
that will capture audio in real use.

Export as `.m4a` or `.wav`, then AirDrop or transfer to iMac.

## Recording Script

Read each prompt naturally. Don't rush, speak at your normal pace.

### Block 1: Normal Conversational English (quiet room)
1. "I'm heading to the office now, I should be there in about twenty minutes. Can you check if the meeting is still at three?"
2. "The weather looks pretty nice today. I was thinking we could grab lunch outside, maybe at that new place on the corner."
3. "Hey, I just finished reviewing the paper. The methodology section needs some work, but the results look promising."
4. "So basically what happened was, the server went down around midnight and nobody noticed until this morning."

### Block 2: Normal Conversational Chinese (quiet room)
5. "我现在在回家的路上，大概还有十五分钟。你要不要我顺便带点什么？"
6. "今天的实验结果还不错，不过有几个参数需要再调一下，我觉得还能优化。"
7. "哎你知道吗，昨天那个会开了两个小时，最后什么结论都没有，真是浪费时间。"
8. "周末有什么计划吗？我想去那个新开的餐厅试试，听说还不错的。"

### Block 3: Phone Call Style (slightly louder, more animated)
9. "Hello? Yeah, I can hear you. So what's the update on that thing we discussed yesterday?"
10. "喂？嗯对，我在呢。你说的那个事情我看了，没问题，就按你说的来吧。"

### Block 4: Tired/Relaxed Voice (softer, slower)
11. "I'm so tired today... I've been working on this since like eight this morning. I think I just need some coffee."
12. "算了吧，太累了，明天再说吧。今天先到这里，回去休息。"

### Block 5: Reading/Presenting Style (clear, measured pace)
13. "The proposed framework leverages multimodal sensing data to construct behavioral context representations. We evaluate our approach on three benchmark datasets."
14. "Our results demonstrate a significant improvement in prediction accuracy, with the model achieving an F1 score of point nine two on the validation set."

### Block 6: Excited/Happy (more energy, higher pitch)
15. "Oh wow, that's amazing! I didn't expect it to work that well on the first try!"
16. "太好了太好了！终于搞定了！我跟你说这个bug找了三天！"

### Block 7: With Background Noise (kitchen, cafe, or outside)
17. (Same content doesn't matter — just speak naturally for 10 seconds in a slightly noisy environment)
18. (Walk outside or stand near a window and talk about anything for 10 seconds)

### Block 8: Whispering/Low Voice (library/bedroom level)
19. (Whisper) "I don't want to wake anyone up, but I need to finish this before tomorrow morning."
20. (Low voice) "嗯，好的好的，我知道了，小声点。"

## File Naming

Name files: `enroll_01.m4a`, `enroll_02.m4a`, ... `enroll_20.m4a`

Place all files in: `/Users/zwang/projects/ryanhub/data/voice-enrollment/`

## After Recording

Run enrollment:
```bash
curl -X POST http://localhost:18790/popo/voice/enroll \
  -F "speaker_name=zhiyuan" \
  -F "audio=@enroll_01.m4a" \
  -F "audio=@enroll_02.m4a"
```

Or batch enroll all files:
```bash
curl -X POST http://localhost:18790/popo/voice/enroll-batch \
  -H "Content-Type: application/json" \
  -d '{"speaker_name": "zhiyuan", "directory": "/Users/zwang/projects/ryanhub/data/voice-enrollment/"}'
```

## Tips

- More samples = better accuracy (20 is great, 30+ is excellent)
- Variety matters more than quantity — cover different moods, volumes, languages
- Background noise samples help the model be robust in real conditions
- Keep each sample clean — only YOUR voice, no overlapping speakers
