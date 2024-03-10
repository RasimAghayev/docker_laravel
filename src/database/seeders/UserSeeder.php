<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class UserSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        User::factory()
            ->times(5)
            ->hasPosts(20)
            ->hasComments(20)
            ->create();

        /*

        User::factory(5)->create()
        ->each(function ($user) {
            $user_id = $user->id;
            Post::create([
                'user_id' => $user_id,
                'title' => fake()->text(32),
                'content' => fake()->text(128),
            ])
                ->each(function ($post, $user_id) {
                    Comment::create([
                        'user_id' => $user_id,
                        'post_id' => $post->id,
                        'content' => fake()->text(128),
                    ]);
                });
        });
        */
    }
}
