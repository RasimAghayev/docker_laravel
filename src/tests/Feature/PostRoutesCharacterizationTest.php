<?php

namespace Tests\Feature;

use App\Models\Comment;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PostRoutesCharacterizationTest extends TestCase
{
    use RefreshDatabase;

    public function test_posts_index_returns_all_posts(): void
    {
        $user = User::factory()->create();
        $post = Post::factory()->for($user)->create();

        $response = $this->getJson('/posts');

        $response->assertStatus(200)
            ->assertJsonCount(1)
            ->assertJsonPath('0.id', $post->id);
    }

    public function test_post_show_returns_the_post(): void
    {
        $user = User::factory()->create();
        $post = Post::factory()->for($user)->create();

        $response = $this->getJson('/posts/'.$post->id);

        $response->assertStatus(200)
            ->assertJsonPath('id', $post->id)
            ->assertJsonPath('title', $post->title);
    }

    public function test_post_comments_index_returns_comments(): void
    {
        $user = User::factory()->create();
        $post = Post::factory()->for($user)->create();
        $comment = Comment::factory()->create([
            'post_id' => $post->id,
            'user_id' => $user->id,
        ]);

        $response = $this->getJson('/posts/'.$post->id.'/comments');

        $response->assertStatus(200)
            ->assertJsonCount(1)
            ->assertJsonPath('0.id', $comment->id);
    }

    public function test_comment_show_returns_the_comment(): void
    {
        $user = User::factory()->create();
        $post = Post::factory()->for($user)->create();
        $comment = Comment::factory()->create([
            'post_id' => $post->id,
            'user_id' => $user->id,
        ]);

        $response = $this->getJson('/posts/'.$post->id.'/comments/'.$comment->id);

        $response->assertStatus(200)
            ->assertJsonPath('id', $comment->id)
            ->assertJsonPath('post_id', $post->id);
    }
}