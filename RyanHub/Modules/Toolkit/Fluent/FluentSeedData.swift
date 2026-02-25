import Foundation

// MARK: - Fluent Seed Data

/// Seed vocabulary data for the Fluent module.
/// A curated subset of the full PWA vocabulary across all categories.
enum FluentSeedData {

    /// All seed vocabulary items.
    static let allVocabulary: [VocabularyItem] = {
        return [
            // =================================================================
            // STRATEGY
            // =================================================================
            v("North Star",
              def: "The overarching goal or guiding metric that directs all decisions.",
              zh: "北极星指标", cat: .strategy,
              ex: ["Our north star for this quarter is reducing inference latency by 40%."],
              related: ["OKR", "KPI"]),
            v("Move the Needle",
              def: "To make a meaningful, measurable impact.",
              zh: "产生实质影响", cat: .strategy,
              ex: ["The new compression algorithm is interesting, but will it actually move the needle on real-time performance?"]),
            v("Low-Hanging Fruit",
              def: "Easy wins; tasks that require minimal effort but yield clear results.",
              zh: "容易摘的果子", cat: .strategy,
              ex: ["Before we redesign the whole pipeline, let's grab the low-hanging fruit."]),
            v("Double Down On",
              def: "To increase commitment to a strategy or direction.",
              zh: "加倍投入", cat: .strategy,
              ex: ["After seeing the Q3 results, leadership wants to double down on our on-device ML approach."]),
            v("Table This",
              def: "To postpone or set aside a topic for later discussion.",
              zh: "暂时搁置", cat: .strategy,
              ex: ["Good point, but let's table this and revisit after we have more data."]),
            v("Pivot",
              def: "To fundamentally change strategy or direction based on new information.",
              zh: "战略转型", cat: .strategy,
              ex: ["We need to pivot from B2B to B2C based on the market research."]),

            // =================================================================
            // EXECUTION
            // =================================================================
            v("Ship It",
              def: "To release or deploy a product, feature, or update.",
              zh: "发布上线", cat: .execution,
              ex: ["We've tested enough — let's ship it and iterate."]),
            v("Bandwidth",
              def: "Available capacity (time/resources) to take on work.",
              zh: "带宽/精力", cat: .execution,
              ex: ["I don't have the bandwidth to take on another project this sprint."]),
            v("Scope Creep",
              def: "Uncontrolled expansion of project requirements beyond the original plan.",
              zh: "需求蔓延", cat: .execution,
              ex: ["We need to push back on this scope creep or we'll never hit the deadline."]),
            v("Unblock",
              def: "To remove an obstacle preventing progress on a task.",
              zh: "解除阻碍", cat: .execution,
              ex: ["Can you unblock me on the API access? I've been waiting since Monday."]),
            v("Iterate",
              def: "To make repeated small improvements based on feedback.",
              zh: "迭代改进", cat: .execution,
              ex: ["Let's ship the MVP and iterate based on user feedback."]),
            v("Deep Dive",
              def: "A thorough, detailed analysis or investigation of a topic.",
              zh: "深入研究", cat: .execution,
              ex: ["I'll do a deep dive into the performance metrics this afternoon."]),

            // =================================================================
            // COMMUNICATION
            // =================================================================
            v("Circle Back",
              def: "To return to a topic or follow up later.",
              zh: "回头再讨论", cat: .communication,
              ex: ["Let me circle back on that after I check with the team."]),
            v("Take It Offline",
              def: "To discuss something outside the current meeting to avoid derailing.",
              zh: "会后单聊", cat: .communication,
              ex: ["This is getting detailed — let's take it offline after the standup."]),
            v("On the Same Page",
              def: "Having a shared understanding of a situation or plan.",
              zh: "达成共识", cat: .communication,
              ex: ["Before we proceed, I want to make sure we're all on the same page."]),
            v("Heads Up",
              def: "An advance warning or notification about something.",
              zh: "提前告知", cat: .communication,
              ex: ["Just a heads up — the deployment window changed to Thursday."]),
            v("Loop In",
              def: "To include someone in a communication or decision.",
              zh: "拉入讨论", cat: .communication,
              ex: ["Can you loop in the design team? They'll want to weigh in on this."]),

            // =================================================================
            // MEETING
            // =================================================================
            v("Standup",
              def: "A brief daily meeting where team members share progress and blockers.",
              zh: "站会", cat: .meeting,
              ex: ["In standup yesterday, Sarah mentioned she's blocked on the API integration."]),
            v("Action Item",
              def: "A specific task assigned to someone as an outcome of a meeting.",
              zh: "待办事项", cat: .meeting,
              ex: ["Let me capture the action items from today's discussion."]),
            v("Sync Up",
              def: "A meeting to align on progress, plans, or status.",
              zh: "同步会议", cat: .meeting,
              ex: ["Let's sync up tomorrow morning to align on the launch plan."]),
            v("Retro",
              def: "A meeting to reflect on what went well, what didn't, and improvements.",
              zh: "复盘会", cat: .meeting,
              ex: ["In the sprint retro, the team agreed we need better test coverage."]),

            // =================================================================
            // PEOPLE & CAREER
            // =================================================================
            v("Stakeholder",
              def: "A person or group with interest or influence in a project's outcome.",
              zh: "利益相关者", cat: .people,
              ex: ["We need to get buy-in from all stakeholders before moving forward."]),
            v("Mentor",
              def: "An experienced person who guides someone's professional development.",
              zh: "导师", cat: .career,
              ex: ["My mentor helped me navigate the promotion process."]),
            v("Ramp Up",
              def: "To gradually increase effort, speed, or scale; to get up to speed.",
              zh: "逐步提升/上手", cat: .career,
              ex: ["It takes about two months to fully ramp up on a new codebase."]),
            v("Leverage",
              def: "To use a resource or advantage effectively to achieve a goal.",
              zh: "利用/借力", cat: .career,
              ex: ["We can leverage our existing user base to test the new feature."]),

            // =================================================================
            // IDIOMS
            // =================================================================
            v("The Ball Is in Your Court",
              def: "It's your turn to take action or make a decision.",
              zh: "球在你这边（轮到你了）", cat: .idioms,
              ex: ["I've shared the proposal — the ball is in your court now."]),
            v("Bite the Bullet",
              def: "To endure a painful or difficult situation with courage.",
              zh: "咬紧牙关", cat: .idioms,
              ex: ["We need to bite the bullet and refactor the legacy code."]),
            v("Hit the Ground Running",
              def: "To start something and proceed quickly with full effort.",
              zh: "迅速上手", cat: .idioms,
              ex: ["The new hire hit the ground running and shipped code in her first week."]),
            v("Burning the Midnight Oil",
              def: "Working late into the night.",
              zh: "挑灯夜战", cat: .idioms,
              ex: ["The team has been burning the midnight oil to meet the deadline."]),
            v("Back to Square One",
              def: "To return to the beginning after a failed attempt.",
              zh: "回到原点", cat: .idioms,
              ex: ["The prototype failed testing — we're back to square one."]),

            // =================================================================
            // PHRASAL VERBS
            // =================================================================
            v("Bring Up",
              def: "To raise a topic or subject for discussion.",
              zh: "提起/提出", cat: .phrasalVerbs,
              ex: ["I'll bring up the timeline issue in tomorrow's meeting."]),
            v("Come Up With",
              def: "To think of or produce an idea or solution.",
              zh: "想出", cat: .phrasalVerbs,
              ex: ["We need to come up with a better onboarding flow."]),
            v("Follow Up",
              def: "To take further action after an initial step.",
              zh: "跟进", cat: .phrasalVerbs,
              ex: ["I'll follow up with the vendor about the pricing."]),
            v("Figure Out",
              def: "To understand or solve something through thinking.",
              zh: "弄清楚", cat: .phrasalVerbs,
              ex: ["Let me figure out why the tests are failing."]),
            v("Break Down",
              def: "To divide something into smaller, manageable parts.",
              zh: "拆解", cat: .phrasalVerbs,
              ex: ["Can you break down the feature into smaller tasks?"]),
            v("Sort Out",
              def: "To resolve or organize something.",
              zh: "解决/整理", cat: .phrasalVerbs,
              ex: ["Let's sort out the merge conflicts before the demo."]),

            // =================================================================
            // DAILY LIFE
            // =================================================================
            v("Rain Check",
              def: "To postpone an invitation with the intention of accepting later.",
              zh: "改天再约", cat: .dailyLife,
              ex: ["I can't make dinner tonight — can I take a rain check?"]),
            v("Grab a Bite",
              def: "To eat something quickly, often casually.",
              zh: "随便吃点", cat: .dailyLife,
              ex: ["Want to grab a bite after the meeting?"]),
            v("Hang Out",
              def: "To spend time casually with others.",
              zh: "一起玩/闲逛", cat: .dailyLife,
              ex: ["We should hang out this weekend."]),

            // =================================================================
            // SLANG & CASUAL
            // =================================================================
            v("No-Brainer",
              def: "A decision or choice that is extremely easy or obvious.",
              zh: "显而易见的选择", cat: .slangCasual,
              ex: ["Using TypeScript for the new project was a no-brainer."]),
            v("GOAT",
              def: "Greatest Of All Time — used to describe the best in a category.",
              zh: "史上最佳", cat: .slangCasual,
              ex: ["That debugging session was legendary — you're the GOAT."]),
            v("Lowkey",
              def: "Subtly, secretly, or to a moderate degree.",
              zh: "低调地/暗暗地", cat: .slangCasual,
              ex: ["I'm lowkey stressed about the presentation tomorrow."]),

            // =================================================================
            // EMOTIONS & REACTIONS
            // =================================================================
            v("Stoked",
              def: "Very excited and enthusiastic.",
              zh: "超级兴奋", cat: .emotionsReactions,
              ex: ["I'm stoked about the new project — it's exactly what I wanted to work on."]),
            v("Gutted",
              def: "Extremely disappointed or upset.",
              zh: "非常失望", cat: .emotionsReactions,
              ex: ["I was gutted when the offer fell through."]),
            v("Over the Moon",
              def: "Extremely happy or delighted.",
              zh: "欣喜若狂", cat: .emotionsReactions,
              ex: ["She was over the moon when she got the promotion."]),

            // =================================================================
            // TECH JARGON
            // =================================================================
            v("Technical Debt",
              def: "Accumulated shortcuts or suboptimal code that needs future cleanup.",
              zh: "技术债务", cat: .techJargon,
              ex: ["We need to allocate time to pay down our technical debt."]),
            v("Bikeshedding",
              def: "Spending disproportionate time on trivial issues instead of important ones.",
              zh: "纠结于细枝末节", cat: .techJargon,
              ex: ["Let's stop bikeshedding about the button color and focus on the architecture."]),
            v("Dogfooding",
              def: "Using your own product internally before releasing to customers.",
              zh: "内部试用", cat: .techJargon,
              ex: ["We've been dogfooding the app for two weeks and found several issues."]),
            v("Rubber Duck Debugging",
              def: "Explaining your code line by line to find bugs, as if talking to a rubber duck.",
              zh: "小黄鸭调试法", cat: .techJargon,
              ex: ["I was stuck for hours until I tried rubber duck debugging."]),

            // =================================================================
            // CONFLICT RESOLUTION
            // =================================================================
            v("Push Back",
              def: "To resist or oppose a request or decision.",
              zh: "反对/推回", cat: .conflictResolution,
              ex: ["Don't be afraid to push back if the deadline is unrealistic."]),
            v("Meet Halfway",
              def: "To compromise, with each side making concessions.",
              zh: "各让一步", cat: .conflictResolution,
              ex: ["Let's meet halfway — we'll reduce scope but keep the timeline."]),
            v("Clear the Air",
              def: "To resolve tension or misunderstandings through open discussion.",
              zh: "消除误会", cat: .conflictResolution,
              ex: ["After the heated debate, they had a one-on-one to clear the air."]),

            // =================================================================
            // ACADEMIC WRITING
            // =================================================================
            v("Furthermore",
              def: "In addition; used to add information to a point.",
              zh: "此外/而且", cat: .academicWriting,
              ex: ["Furthermore, the results indicate a significant correlation between the two variables."]),
            v("Nevertheless",
              def: "In spite of that; however.",
              zh: "尽管如此", cat: .academicWriting,
              ex: ["The sample size was small; nevertheless, the findings are promising."]),
            v("Corroborate",
              def: "To confirm or support a statement with evidence.",
              zh: "证实/佐证", cat: .academicWriting,
              ex: ["These findings corroborate previous research in the field."]),

            // =================================================================
            // PROVERBS & WISDOM
            // =================================================================
            v("Don't Put All Your Eggs in One Basket",
              def: "Don't risk everything on a single venture or plan.",
              zh: "不要把鸡蛋放在一个篮子里", cat: .proverbsWisdom,
              ex: ["We should diversify our revenue streams — don't put all your eggs in one basket."]),
            v("Actions Speak Louder Than Words",
              def: "What people do is more important than what they say.",
              zh: "行动胜于言语", cat: .proverbsWisdom,
              ex: ["He promised to help, but actions speak louder than words."]),

            // =================================================================
            // ASSESSMENT
            // =================================================================
            v("Bottleneck",
              def: "A point of congestion or obstruction that limits throughput.",
              zh: "瓶颈", cat: .assessment,
              ex: ["The database is the bottleneck — everything else is fast."]),
            v("Pain Point",
              def: "A specific problem or frustration experienced by users or teams.",
              zh: "痛点", cat: .assessment,
              ex: ["The onboarding flow is the biggest pain point for new users."]),
            v("Ballpark",
              def: "A rough estimate or approximate range.",
              zh: "大概的估计", cat: .assessment,
              ex: ["Can you give me a ballpark estimate on how long this will take?"]),
            v("Sanity Check",
              def: "A quick test to verify basic correctness before proceeding.",
              zh: "基本验证", cat: .assessment,
              ex: ["Let's do a sanity check on the numbers before presenting to the board."]),

            // =================================================================
            // FOOD & DINING
            // =================================================================
            v("Potluck",
              def: "A meal where each guest brings a dish to share.",
              zh: "每人带一道菜的聚餐", cat: .foodDining,
              ex: ["We're having a team potluck on Friday — I'm bringing pasta."]),
            v("Foodie",
              def: "A person with a keen interest in food and dining.",
              zh: "美食爱好者", cat: .foodDining,
              ex: ["She's a total foodie — she always knows the best restaurants."]),

            // =================================================================
            // NETWORKING
            // =================================================================
            v("Elevator Pitch",
              def: "A brief, persuasive summary of an idea, delivered in ~30 seconds.",
              zh: "电梯演讲", cat: .networking,
              ex: ["You need a solid elevator pitch ready for the conference."]),
            v("Touch Base",
              def: "To briefly connect or communicate with someone.",
              zh: "简短联系", cat: .networking,
              ex: ["Let me touch base with the client before we finalize."]),

            // =================================================================
            // HUMOR
            // =================================================================
            v("Tongue-in-Cheek",
              def: "Humorous or ironic; not meant to be taken seriously.",
              zh: "半开玩笑的", cat: .humor,
              ex: ["His comment about 'just rewriting everything in Rust' was tongue-in-cheek."]),

            // =================================================================
            // SOCIAL & RELATIONSHIPS
            // =================================================================
            v("Break the Ice",
              def: "To initiate conversation in an awkward or unfamiliar social situation.",
              zh: "打破僵局", cat: .socialRelationships,
              ex: ["I used a fun question to break the ice at the team dinner."]),
            v("Hit It Off",
              def: "To quickly develop a good relationship with someone.",
              zh: "一见如故", cat: .socialRelationships,
              ex: ["We hit it off immediately at the conference."]),
        ]
    }()

    // MARK: - Helper

    private static func v(
        _ term: String,
        def: String,
        zh: String? = nil,
        cat: VocabCategory,
        ex: [String],
        notes: String? = nil,
        related: [String]? = nil
    ) -> VocabularyItem {
        VocabularyItem(
            id: stableId(for: term),
            term: term,
            definition: def,
            chineseDefinition: zh,
            category: cat,
            examples: ex,
            usageNotes: notes,
            relatedTerms: related,
            createdAt: Date(timeIntervalSinceReferenceDate: 0),
            updatedAt: Date(timeIntervalSinceReferenceDate: 0)
        )
    }

    /// Generate a deterministic ID based on the term to avoid duplication.
    private static func stableId(for term: String) -> String {
        let normalized = term.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "'", with: "")
        return "seed-\(normalized)"
    }
}
