const { z } = require("zod");

const submitQuizSchema = z.object({
    answers: z
        .array(
            z.object({
                questionId: z.number().int().positive(),

                answer: z.enum([
                    "A",
                    "B",
                    "C",
                    "D"
                ])
            })
        )
        // May be empty or partial: when the timer runs out the client submits
        // whatever was answered and unanswered questions are graded as wrong.
});

module.exports = {
    submitQuizSchema
};