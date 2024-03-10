<?php

namespace Tests\Unit;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

// use PHPUnit\Framework\TestCase;

class PostTest extends TestCase
{
    use RefreshDatabase;

    /** @test */
    public function testShowPosts()
    {
        $users = User::factory()
                    ->count(5)
                    ->hasPosts(1)
                    ->create();
        $this->assertDatabaseCount('users', 5);
    }
}
